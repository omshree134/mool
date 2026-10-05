import os
import logging
from typing import Optional
from fastapi import APIRouter, Request, Response, BackgroundTasks, Form, Query
from pydantic import BaseModel

from ..voice.prosody import extract_acoustic_features, compute_voice_stress_score
from ..voice.asr import fetch_and_purge_twilio_recording, transcribe_audio_bytes
from ..nlp.emotion import analyze_emotion
from ..engine.scoring import ScoringEngine, DistressInputs
from ..routers.ingest import ingest_observation, ObservationRequest
from ..routers.cases import record_case_event, CaseEventCreate

logger = logging.getLogger("mool-api.routers.ivrs")
router = APIRouter(prefix="/ivrs", tags=["Interactive Voice Response System (IVRS)"])


def twiml_response(content: str) -> Response:
    xml = f'<?xml version="1.0" encoding="UTF-8"?><Response>{content}</Response>'
    return Response(content=xml, media_type="application/xml")


@router.post("/start")
async def ivrs_start(bid: str = Query(...), lang: str = Query("hi")):
    """
    Initial entrypoint when an automated or scheduled IVRS call connects.
    Prompts the caller in their chosen language to rate sleep quality (1 to 3).
    """
    greet_text = (
        "नमस्ते। मूल वेलनेस चेक-इन में आपका स्वागत है। पिछले कुछ दिनों में आपकी नींद कैसी रही? अच्छी नींद के लिए एक दबाएं, मध्यम के लिए दो, या खराब नींद के लिए तीन दबाएं।"
        if lang == "hi"
        else "Hello and welcome to your Mool check-in. How has your sleep been recently? Press 1 for restful, 2 for fair, or 3 for disturbed."
    )

    content = f"""
    <Say language="{ 'hi-IN' if lang == 'hi' else 'en-IN' }">{greet_text}</Say>
    <Gather input="dtmf" numDigits="1" timeout="7" action="/ivrs/answer?bid={bid}&amp;lang={lang}&amp;q=sleep">
        <Say language="{ 'hi-IN' if lang == 'hi' else 'en-IN' }">कृपया अब एक, दो, या तीन दबाएं।</Say>
    </Gather>
    <Redirect>/ivrs/answer?bid={bid}&amp;lang={lang}&amp;q=sleep</Redirect>
    """
    return twiml_response(content)


@router.post("/answer")
async def ivrs_answer(
    request: Request,
    bid: str = Query(...),
    lang: str = Query("hi"),
    q: str = Query("sleep"),
    Digits: Optional[str] = Form(None)
):
    """
    Processes DTMF keypad responses.
    If the caller answers '1' (yes) to the intimidation question, an intimidation
    event is created immediately, alerting responders without waiting for the call to finish.
    """
    digit = Digits or "2"
    logger.info(f"IVRS answer for {bid} on question '{q}': {digit}")

    if q == "sleep":
        # Question 2: Mood
        mood_text = (
            "धन्यवाद। आज आपका मन कैसा महसूस कर रहा है? शांत के लिए एक दबाएं, थोड़ा परेशान के लिए दो, या बहुत उदास या चिंतित के लिए तीन दबाएं।"
            if lang == "hi"
            else "Thank you. How is your mood feeling today? Press 1 for calm, 2 for uneasy, or 3 for anxious or overwhelmed."
        )
        content = f"""
        <Gather input="dtmf" numDigits="1" timeout="7" action="/ivrs/answer?bid={bid}&amp;lang={lang}&amp;q=mood&amp;sleep_val={digit}">
            <Say language="{ 'hi-IN' if lang == 'hi' else 'en-IN' }">{mood_text}</Say>
        </Gather>
        <Redirect>/ivrs/answer?bid={bid}&amp;lang={lang}&amp;q=mood&amp;sleep_val={digit}</Redirect>
        """
        return twiml_response(content)

    elif q == "mood":
        # Question 3: Security & Threats
        threat_text = (
            "सुरक्षा प्रश्न: क्या पिछले दिनों में किसी ने आपको या आपके परिवार को डराया, धमकाया या दबाव डाला है? हां के लिए एक दबाएं, नहीं के लिए दो दबाएं।"
            if lang == "hi"
            else "Security check: Has anyone threatened, pressured, or followed you since we last spoke? Press 1 for Yes, or 2 for No."
        )
        content = f"""
        <Gather input="dtmf" numDigits="1" timeout="7" action="/ivrs/answer?bid={bid}&amp;lang={lang}&amp;q=threat&amp;mood_val={digit}">
            <Say language="{ 'hi-IN' if lang == 'hi' else 'en-IN' }">{threat_text}</Say>
        </Gather>
        <Redirect>/ivrs/answer?bid={bid}&amp;lang={lang}&amp;q=threat&amp;mood_val={digit}</Redirect>
        """
        return twiml_response(content)

    elif q == "threat":
        # Check for threat
        if digit == "1":
            logger.warning(f"THREAT REPORTED via IVRS keypad by beneficiary {bid}!")
            await record_case_event(
                CaseEventCreate(
                    bid=bid,
                    event_type="intimidation",
                    title="Threat Reported via IVRS Call",
                    description="Caller pressed 1 confirming threats, pressure, or intimidation.",
                    source="ivrs_hotline",
                    metadata={"channel": "ivrs", "dtmf": "1"}
                ),
                user={"uid": "ivrs_system"}
            )

        # Prompt voice reflection
        voice_prompt = (
            "यदि आप कुछ कहना चाहते हैं, तो बीप के बाद अपनी बात कहें। आपकी बात पूरी तरह गोपनीय है।"
            if lang == "hi"
            else "If there is anything you would like to share, please speak after the tone. Your voice reflection is strictly private."
        )
        content = f"""
        <Say language="{ 'hi-IN' if lang == 'hi' else 'en-IN' }">{voice_prompt}</Say>
        <Record maxLength="45" timeout="4" action="/ivrs/recording-callback?bid={bid}&amp;lang={lang}" playBeep="true" />
        <Say language="{ 'hi-IN' if lang == 'hi' else 'en-IN' }">धन्यवाद। हम हमेशा आपके साथ हैं।</Say>
        """
        return twiml_response(content)

    return twiml_response("<Say>Thank you for calling Mool.</Say>")


async def process_recording_background(bid: str, recording_url: str, lang: str):
    """
    Background worker that extracts prosody, transcribes, analyzes emotion,
    and purges audio from third-party Twilio storage within seconds.
    """
    logger.info(f"Starting background recording processing for {bid}: {recording_url}")
    audio_bytes, purged = await fetch_and_purge_twilio_recording(recording_url)

    if not audio_bytes:
        logger.warning(f"No audio bytes retrieved for {bid}.")
        return

    # 1. Acoustic prosody feature extraction
    acoustic_features = extract_acoustic_features(audio_bytes)
    voice_stress, z_details = compute_voice_stress_score(bid, acoustic_features)

    # 2. Whisper speech-to-text
    transcript = await transcribe_audio_bytes(audio_bytes, filename=f"{bid}_rec.wav", lang=lang)

    # 3. Emotion NLP classification
    emotion_res = analyze_emotion(transcript) if transcript else None

    logger.info(f"Processed IVRS recording for {bid}. Voice stress: {voice_stress}, Transcript length: {len(transcript)}")

    # 4. Ingest unified observation
    await ingest_observation(
        ObservationRequest(
            bid=bid,
            channel="ivrs",
            kind="voice",
            payload={
                "transcript": transcript,
                "emotions": emotion_res.emotions.model_dump() if emotion_res else {},
                "evidence": emotion_res.evidence if emotion_res else [],
            },
            features={
                "stress_score": voice_stress,
                "acoustic": acoustic_features,
                "z_scores": z_details,
            }
        ),
        user={"uid": "ivrs_worker"}
    )


@router.post("/recording-callback")
async def recording_callback(
    bg_tasks: BackgroundTasks,
    bid: str = Query(...),
    lang: str = Query("hi"),
    RecordingUrl: Optional[str] = Form(None)
):
    """
    Receives recording completion webhook from Twilio.
    Returns immediate closure TwiML within 1 second to avoid Twilio 15s timeout,
    and schedules audio processing + purging in FastAPI BackgroundTasks.
    """
    if RecordingUrl:
        bg_tasks.add_task(process_recording_background, bid, RecordingUrl, lang)

    closing = (
        "आपकी रिकॉर्डिंग प्राप्त हो गई है। याद रखें, आप कभी अकेले नहीं हैं। यदि तुरंत सहायता चाहिए, तो 14416 (Tele-MANAS) या 14566 पर कभी भी कॉल कर सकते हैं। धन्यवाद।"
        if lang == "hi"
        else "Your check-in has been received. Remember that you are not alone. 24/7 free support is always available at 14416 (Tele-MANAS) or 14566. Take care."
    )
    content = f"""
    <Say language="{ 'hi-IN' if lang == 'hi' else 'en-IN' }">{closing}</Say>
    <Hangup />
    """
    return twiml_response(content)
