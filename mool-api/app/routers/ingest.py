import os
import uuid
import logging
from datetime import datetime, timezone
from typing import Dict, Any, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from ..deps import get_current_user
from ..engine.scoring import ScoringEngine, DistressInputs, DistressScoreResult

logger = logging.getLogger("mool-api.routers.ingest")
router = APIRouter(prefix="/ingest", tags=["Multi-Channel Ingestion"])

# In-memory mock store for local prototyping / offline testing
_mock_observations = []
_mock_scores = {}


class ObservationRequest(BaseModel):
    bid: str
    channel: str = Field(..., description="app | ivrs | whatsapp | sms | counsellor")
    kind: str = Field(..., description="checkin | screener | voice | text | event")
    payload: Dict[str, Any] = Field(default_factory=dict)
    features: Dict[str, Any] = Field(default_factory=dict)

    # Optional explicit context hints if provided with check-in
    next_hearing_days: Optional[int] = None
    intimidation_hours_ago: Optional[float] = None
    compensation_overdue_days: Optional[int] = None
    days_since_last_contact: int = 0


class IngestResponse(BaseModel):
    status: str
    oid: str
    bid: str
    timestamp: str
    score_result: DistressScoreResult


@router.post("", response_model=IngestResponse)
async def ingest_observation(obs: ObservationRequest, user: dict = Depends(get_current_user)):
    """
    Unified multi-channel intake endpoint.
    Accepts check-ins, questionnaires, speech prosody, or caseworker logs,
    persists the observation, and computes the updated distress score.
    """
    oid = f"obs_{uuid.uuid4().hex[:12]}"
    now_iso = datetime.now(timezone.utc).isoformat()

    logger.info(f"Ingesting observation {oid} for beneficiary {obs.bid} via {obs.channel} ({obs.kind})")

    # Map observation payload to distress engine inputs
    self_report_val = None
    lang_val = None
    voice_val = None
    behaviour_val = None
    crisis_flag = False
    crisis_reason = None

    if obs.kind == "checkin":
        # Extract mood and sleep from check-in (1 to 3 scale or 0-100)
        mood = obs.payload.get("mood", 2)  # 1 (great) to 3 (hard) or reverse
        sleep = obs.payload.get("sleep", 2)
        if isinstance(mood, (int, float)) and mood <= 3:
            # Scale 1-3 to 0-100
            self_report_val = ((mood - 1) / 2.0) * 80.0 + 20.0
        elif isinstance(mood, (int, float)):
            self_report_val = float(mood)

        # Check for free text sentiment
        note = obs.payload.get("note", "")
        if note and any(w in note.lower() for w in ["dar", "scared", "threat", "suicide", "end it", "khatham"]):
            crisis_flag = any(w in note.lower() for w in ["suicide", "end it", "mar jana"])
            if crisis_flag:
                crisis_reason = "Distress keyword detected in check-in note"
            lang_val = 85.0
        elif note:
            lang_val = 40.0

    elif obs.kind == "screener":
        # PHQ-9, GAD-7, PCL-5, or ISI
        score_val = obs.payload.get("score")
        max_score = obs.payload.get("max_score", 27.0)
        if score_val is not None:
            self_report_val = min(100.0, (float(score_val) / float(max_score)) * 100.0)
        if obs.payload.get("item9_positive", False):
            crisis_flag = True
            crisis_reason = "Item 9 of PHQ-9 self-harm question answered positively"

    elif obs.kind == "voice":
        voice_val = float(obs.features.get("stress_score", 50.0))

    elif obs.kind == "text":
        lang_val = float(obs.features.get("sentiment_distress", 50.0))

    # Compute updated distress score
    score_inputs = DistressInputs(
        bid=obs.bid,
        self_report=self_report_val,
        behaviour=behaviour_val,
        language=lang_val,
        voice=voice_val,
        next_hearing_days=obs.next_hearing_days,
        intimidation_hours_ago=obs.intimidation_hours_ago,
        compensation_overdue_days=obs.compensation_overdue_days,
        days_since_last_contact=obs.days_since_last_contact,
        explicit_crisis_flag=crisis_flag,
        crisis_reason=crisis_reason,
    )

    score_result = ScoringEngine.compute(score_inputs)

    # Record observation in mock memory store
    record = {
        "oid": oid,
        "bid": obs.bid,
        "channel": obs.channel,
        "kind": obs.kind,
        "payload": obs.payload,
        "features": obs.features,
        "created_at": now_iso,
        "score": score_result.score,
        "tier": score_result.tier,
    }
    _mock_observations.append(record)
    _mock_scores[obs.bid] = score_result

    return IngestResponse(
        status="ingested",
        oid=oid,
        bid=obs.bid,
        timestamp=now_iso,
        score_result=score_result
    )
