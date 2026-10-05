import os
import io
import logging
from typing import Optional, Tuple
import httpx
from groq import Groq
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("mool-api.voice.asr")


async def transcribe_audio_bytes(audio_bytes: bytes, filename: str = "recording.wav", lang: Optional[str] = None) -> str:
    """
    Transcribes audio bytes using Groq's high-speed Whisper speech-to-text API.
    """
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        logger.warning("GROQ_API_KEY missing for ASR transcription.")
        return ""

    try:
        client = Groq(api_key=api_key)
        # Prepare file-like tuple for Whisper API
        file_tuple = (filename, io.BytesIO(audio_bytes), "audio/wav")
        params = {
            "file": file_tuple,
            "model": "whisper-large-v3",
            "temperature": 0.0,
            "response_format": "text",
        }
        if lang in ["en", "hi", "mr", "ta", "te", "bn"]:
            params["language"] = lang

        transcription = client.audio.transcriptions.create(**params)
        return str(transcription).strip()
    except Exception as e:
        logger.error(f"Whisper transcription failed: {e}")
        return ""


async def fetch_and_purge_twilio_recording(recording_url: str) -> Tuple[bytes, bool]:
    """
    Downloads audio file from Twilio credentials, then sends a DELETE request
    to purge survivor audio from Twilio third-party servers, ensuring compliance
    with survivor privacy and BNS Section 72.
    """
    sid = os.getenv("TWILIO_SID", "")
    token = os.getenv("TWILIO_TOKEN", "")

    # Ensure URL ends with .wav for lossless extraction
    wav_url = recording_url if recording_url.endswith(".wav") else f"{recording_url}.wav"
    auth = (sid, token) if (sid and token) else None

    audio_bytes = b""
    purged = False

    async with httpx.AsyncClient(timeout=20.0) as client:
        try:
            # 1. Download
            res = await client.get(wav_url, auth=auth)
            if res.status_code == 200:
                audio_bytes = res.content
                logger.info(f"Downloaded {len(audio_bytes)} bytes from Twilio recording.")

            # 2. Purge from Twilio
            if sid and token:
                clean_url = recording_url.replace(".wav", "").replace(".mp3", "")
                del_res = await client.delete(clean_url, auth=auth)
                purged = (del_res.status_code in [200, 204])
                if purged:
                    logger.info("Successfully purged survivor audio from Twilio server.")
                else:
                    logger.warning(f"Twilio purge returned status: {del_res.status_code}")
        except Exception as e:
            logger.error(f"Twilio recording download/purge error: {e}")

    return audio_bytes, purged
