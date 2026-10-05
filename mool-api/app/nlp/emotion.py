import os
import json
import logging
from typing import Dict, List, Optional
from pydantic import BaseModel, Field
from groq import Groq
from dotenv import load_dotenv

from .crisis_lexicon import check_crisis_lexicon
from .pseudonymise import pseudonymise_text

load_dotenv()

logger = logging.getLogger("mool-api.nlp.emotion")

EMOTION_SYSTEM_PROMPT = """You are a clinical trauma NLP evaluator analyzing reflections from victims of violence and atrocities.
Analyze the user's text and output STRICT JSON format with this exact structure:
{
  "emotions": {
    "fear": 0.0,
    "sadness": 0.0,
    "anger": 0.0,
    "hopelessness": 0.0,
    "shame": 0.0,
    "calm": 0.0
  },
  "threat_mentioned": false,
  "crisis_signal": false,
  "evidence": ["short exact span from text that justified the top emotion or threat"]
}
Values in 'emotions' must be floating-point numbers between 0.0 and 1.0 summing approximately to 1.0.
Output ONLY the JSON object. No explanations or markdown backticks."""


class EmotionScores(BaseModel):
    fear: float = 0.0
    sadness: float = 0.0
    anger: float = 0.0
    hopelessness: float = 0.0
    shame: float = 0.0
    calm: float = 0.0


class EmotionAnalysisResult(BaseModel):
    emotions: EmotionScores
    threat_mentioned: bool
    crisis_signal: bool
    lexicon_crisis_match: Optional[str] = None
    evidence: List[str] = Field(default_factory=list)
    pseudonymised_text: str
    composite_distress: float = 0.0


def analyze_emotion(text: str) -> EmotionAnalysisResult:
    """
    Executes the 3-step text evaluation pipeline:
    1. Deterministic crisis check (independent of LLM).
    2. PII pseudonymization under BNS Section 72.
    3. Structured Groq JSON emotion classification with explainable evidence spans.
    """
    if not text or not text.strip():
        return EmotionAnalysisResult(
            emotions=EmotionScores(calm=1.0),
            threat_mentioned=False,
            crisis_signal=False,
            pseudonymised_text="",
            composite_distress=0.0,
        )

    # 1. Deterministic crisis check
    is_crisis_lexicon, crisis_term = check_crisis_lexicon(text)

    # 2. Pseudonymize
    clean_text = pseudonymise_text(text)

    # 3. LLM classification via Groq JSON mode
    api_key = os.getenv("GROQ_API_KEY")
    result_dict = None

    if api_key:
        try:
            client = Groq(api_key=api_key)
            completion = client.chat.completions.create(
                model="qwen/qwen3.8-27b",
                messages=[
                    {"role": "system", "content": EMOTION_SYSTEM_PROMPT},
                    {"role": "user", "content": clean_text},
                ],
                temperature=0.2,
                max_tokens=200,
                response_format={"type": "json_object"},
            )
            raw_json = completion.choices[0].message.content
            if raw_json:
                result_dict = json.loads(raw_json)
        except Exception as e:
            logger.warning(f"Groq emotion classification failed: {e}. Using deterministic heuristic fallback.")

    if not result_dict:
        # Fallback heuristic
        is_threat = any(w in clean_text.lower() for w in ["threat", "follow", "scared", "stalk", "dhamki"])
        is_sad = any(w in clean_text.lower() for w in ["cry", "sad", "hopeless", "dard", "udas"])
        result_dict = {
            "emotions": {
                "fear": 0.6 if is_threat else 0.1,
                "sadness": 0.5 if is_sad else 0.1,
                "anger": 0.1,
                "hopelessness": 0.3 if is_sad else 0.1,
                "shame": 0.0,
                "calm": 0.1 if (is_threat or is_sad) else 0.8,
            },
            "threat_mentioned": is_threat,
            "crisis_signal": is_crisis_lexicon,
            "evidence": [clean_text[:60]] if (is_threat or is_sad) else [],
        }

    emotions_data = result_dict.get("emotions", {})
    scores = EmotionScores(
        fear=float(emotions_data.get("fear", 0.0)),
        sadness=float(emotions_data.get("sadness", 0.0)),
        anger=float(emotions_data.get("anger", 0.0)),
        hopelessness=float(emotions_data.get("hopelessness", 0.0)),
        shame=float(emotions_data.get("shame", 0.0)),
        calm=float(emotions_data.get("calm", 0.0)),
    )

    # Composite language distress formula (0-100)
    # Fear and hopelessness carry highest distress weighting
    distress = (
        scores.fear * 35.0
        + scores.hopelessness * 35.0
        + scores.sadness * 15.0
        + scores.anger * 15.0
    ) * 100.0 / 100.0

    if result_dict.get("threat_mentioned", False):
        distress = min(100.0, distress + 20.0)

    return EmotionAnalysisResult(
        emotions=scores,
        threat_mentioned=result_dict.get("threat_mentioned", False),
        crisis_signal=result_dict.get("crisis_signal", False) or is_crisis_lexicon,
        lexicon_crisis_match=crisis_term,
        evidence=result_dict.get("evidence", []),
        pseudonymised_text=clean_text,
        composite_distress=round(distress, 1),
    )
