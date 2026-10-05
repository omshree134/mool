import os
import logging
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
import httpx
from groq import Groq
from dotenv import load_dotenv

from ..deps import get_current_user

load_dotenv()

logger = logging.getLogger("mool-api.routers.ai")
router = APIRouter(prefix="/ai", tags=["AI & Conversational Companion"])

# Candidate models in priority order
CANDIDATE_MODELS = [
    "qwen/qwen3.8-27b",
    "openai/gpt-oss-120b",
    "openai/gpt-oss-20b",
]

SYSTEM_PROMPT = """You are Mool (मूल), a gentle, grounded, trauma-informed companion for survivors and complainants of atrocities and distress in India.
Your mission is to provide quiet, validating, and calming emotional support.

Core Guidelines:
1. Warmth & Empathy: Listen without judgement. Acknowledge and validate their pain gently.
2. Somatic Grounding: Offer simple, non-intrusive grounding techniques when appropriate (e.g. feeling feet on the floor, 4-7-8 breathing, noticing 3 things around them).
3. Crisis Safety: If the user expresses thoughts of self-harm, ending their life, or immediate danger, immediately offer the 24/7 toll-free national helplines:
   - Tele-MANAS: 14416 (Mental Health)
   - NHAA National Helpline: 14566 (SC/ST Prevention of Atrocities)
   - Emergency: 112
4. Conciseness: Keep responses short, warm, and comforting (2 to 4 sentences). Avoid walls of text.
5. Language: Respond naturally in the user's language (Hindi, English, or Hinglish). Never sound robotic."""


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    lang: Optional[str] = "en"


class ChatResponse(BaseModel):
    reply: str
    model: str
    success: bool = True


def get_groq_client() -> Groq:
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="GROQ_API_KEY environment variable is not configured on the server."
        )
    return Groq(api_key=api_key)


@router.post("/chat", response_model=ChatResponse)
async def chat_proxy(request: ChatRequest, user: dict = Depends(get_current_user)):
    """
    Secure Groq AI proxy endpoint.
    Verifies Firebase token, keeps the API key secret on the server,
    and applies trauma-informed system prompting with automatic model failover.
    """
    client = get_groq_client()

    # Build conversation payload
    formatted_messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    for msg in request.messages:
        if msg.role in ["user", "assistant", "system"]:
            formatted_messages.append({"role": msg.role, "content": msg.content})

    last_error = None
    for model_name in CANDIDATE_MODELS:
        try:
            logger.info(f"Dispatching chat request to Groq model: {model_name}")
            completion = client.chat.completions.create(
                model=model_name,
                messages=formatted_messages,
                temperature=0.6,
                max_tokens=256,
            )
            reply = completion.choices[0].message.content
            if reply and reply.strip():
                return ChatResponse(reply=reply.strip(), model=model_name, success=True)
        except Exception as e:
            logger.warning(f"Model {model_name} failed: {e}. Trying fallback...")
            last_error = e

    # Fallback response if all API models fail
    logger.error(f"All Groq candidate models failed. Last error: {last_error}")
    is_hindi = request.lang == "hi" or any("namaste" in m.content.lower() or "madad" in m.content.lower() for m in request.messages if m.role == "user")
    
    fallback_reply = (
        "मैं आपके साथ हूँ। कृपया गहरी सांस लें और जानें कि आप अकेले नहीं हैं। यदि आपको तुरंत सहायता चाहिए, तो 14416 (Tele-MANAS) या 14566 पर कॉल करें।"
        if is_hindi
        else "I am right here with you. Take a gentle breath and know that you are not alone. If you need immediate human support, free 24/7 help is available at 14416 (Tele-MANAS) or 14566."
    )
    return ChatResponse(reply=fallback_reply, model="fallback_safety", success=False)
