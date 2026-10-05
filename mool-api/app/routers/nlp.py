import logging
from fastapi import APIRouter, Depends
from pydantic import BaseModel

from ..deps import get_current_user
from ..nlp.emotion import analyze_emotion, EmotionAnalysisResult

logger = logging.getLogger("mool-api.routers.nlp")
router = APIRouter(prefix="/nlp", tags=["Emotion AI & Crisis NLP"])


class AnalyzeTextRequest(BaseModel):
    text: str


@router.post("/analyze", response_model=EmotionAnalysisResult)
async def analyze_text(req: AnalyzeTextRequest, user: dict = Depends(get_current_user)):
    """
    Analyzes victim free-text notes, journal reflections, or chat transcripts.
    1. Deterministic keyword crisis check.
    2. BNS Section 72 privacy pseudonymization.
    3. Structured Groq JSON emotion classification with explainability evidence spans.
    """
    return analyze_emotion(req.text)
