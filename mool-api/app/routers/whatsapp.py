import logging
from typing import Optional
from fastapi import APIRouter, Form, Response
from pydantic import BaseModel

from ..nlp.emotion import analyze_emotion
from ..routers.ingest import ingest_observation, ObservationRequest

logger = logging.getLogger("mool-api.routers.whatsapp")
router = APIRouter(prefix="/whatsapp", tags=["WhatsApp Chatbot & SMS Gateway"])


def twilio_messaging_response(message: str) -> Response:
    xml = f'<?xml version="1.0" encoding="UTF-8"?><Response><Message>{message}</Message></Response>'
    return Response(content=xml, media_type="application/xml")


@router.post("/inbound")
async def whatsapp_inbound(
    From: Optional[str] = Form(None),
    Body: Optional[str] = Form(None)
):
    """
    Twilio WhatsApp Sandbox webhook.
    Handles interactive check-in menu, freeform survivor reflections,
    and the 'CALL' keyword for requesting an immediate outbound IVRS check-in.
    """
    phone = From or "unknown_phone"
    text = (Body or "").strip()
    bid = f"wa_{phone.replace('whatsapp:', '').replace('+', '')}"

    logger.info(f"Inbound WhatsApp from {phone}: '{text}'")

    # 1. Trigger Outbound Call Request
    if text.upper() in ["CALL", "PHONE", "CALL ME", "MADAD"]:
        reply = (
            "नमस्ते। आपका कॉल अनुरोध प्राप्त हुआ है। हमारी स्वचालित आईवीआरएस सेवा आपको कुछ ही पलों में कॉल करेगी।\n\n"
            "यदि तत्काल आपातकालीन सहायता की आवश्यकता है, तो सीधे 14416 (Tele-MANAS) या 14566 पर कॉल करें।"
        )
        return twilio_messaging_response(reply)

    # 2. Keypad numeric check-in options
    if text in ["1", "2", "3"]:
        mood_map = {"1": "शांत / अच्छा (Calm)", "2": "मध्यम / थोड़ा तनाव (Uneasy)", "3": "कठिन / बहुत चिंतित (Overwhelmed)"}
        await ingest_observation(
            ObservationRequest(
                bid=bid,
                channel="whatsapp",
                kind="checkin",
                payload={"mood": int(text), "note": f"WhatsApp selected {mood_map.get(text)}"}
            ),
            user={"uid": "whatsapp_gateway"}
        )
        reply = (
            f"धन्यवाद। आपकी स्थिति नोट कर ली गई है: {mood_map.get(text)}।\n\n"
            "यदि आपके पास साझा करने के लिए कुछ और है, तो आप यहाँ कभी भी संदेश भेज सकते हैं। हम हमेशा आपके साथ हैं।"
        )
        return twilio_messaging_response(reply)

    # 3. Freeform text message (NLP emotion & crisis analysis)
    analysis = analyze_emotion(text)
    await ingest_observation(
        ObservationRequest(
            bid=bid,
            channel="whatsapp",
            kind="text",
            payload={
                "message": analysis.pseudonymised_text,
                "emotions": analysis.emotions.model_dump(),
                "evidence": analysis.evidence,
            },
            features={"sentiment_distress": analysis.composite_distress}
        ),
        user={"uid": "whatsapp_gateway"}
    )

    if analysis.crisis_signal or analysis.threat_mentioned:
        reply = (
            "हम आपकी बात सुन रहे हैं और आपकी सुरक्षा हमारे लिए सबसे महत्वपूर्ण है।\n\n"
            "कृपया 24/7 निःशुल्क राष्ट्रीय हेल्पलाइन पर संपर्क करें:\n"
            "• Tele-MANAS: 14416 (मानसिक स्वास्थ्य सहायता)\n"
            "• राष्ट्रीय हेल्पलाइन (NHAA): 14566 (अत्याचार निवारण सुरक्षा)\n\n"
            "कॉल बैक के लिए 'CALL' लिखकर भेजें।"
        )
    else:
        reply = (
            "धन्यवाद। आपका संदेश सुरक्षित रूप से दर्ज कर लिया गया है।\n"
            "दैनिक मूड चेक-इन के लिए:\n"
            "1 - शांत / अच्छा\n"
            "2 - थोड़ा तनाव\n"
            "3 - बहुत चिंतित\n"
            "या फोन पर बात करने के लिए 'CALL' भेजें।"
        )

    return twilio_messaging_response(reply)
