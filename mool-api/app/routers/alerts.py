import logging
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from ..deps import get_current_user
from ..engine.escalation import list_alerts, acknowledge_alert
from ..engine.recommend import list_recommendations, record_recommendation_decision

logger = logging.getLogger("mool-api.routers.alerts")
router = APIRouter(prefix="", tags=["Alerts & Interventions (SLA & XAI)"])


class AckRequest(BaseModel):
    note: Optional[str] = ""


class DecisionRequest(BaseModel):
    decision: str = Field(..., description="accept | reject | done")
    note: Optional[str] = ""


@router.get("/alerts")
async def get_alerts(district_code: Optional[str] = None, status: Optional[str] = None, user: dict = Depends(get_current_user)):
    """Returns alerts filtered by district and status."""
    return list_alerts(district_code=district_code, status=status)


@router.post("/alerts/{aid}/ack")
async def ack_alert(aid: str, req: AckRequest, user: dict = Depends(get_current_user)):
    """Acknowledge an active SLA alert, logging the responder identity and stopping auto-escalation."""
    actor_id = user.get("email") or user.get("uid", "caseworker")
    res = acknowledge_alert(aid=aid, actor_id=actor_id, note=req.note or "")
    if not res:
        raise HTTPException(status_code=404, detail="Alert not found")
    return res


@router.get("/recommendations")
async def get_recommendations(bid: Optional[str] = None, status: Optional[str] = None, user: dict = Depends(get_current_user)):
    """Lists explainable intervention recommendations for caseworkers."""
    return list_recommendations(bid=bid, status=status)


@router.post("/recommendations/{rid}/decision")
async def submit_decision(rid: str, req: DecisionRequest, user: dict = Depends(get_current_user)):
    """
    Submits a caseworker's Accept, Reject, or Done feedback on an intervention recommendation.
    Creates a human-in-the-loop record for auditing and machine learning model retraining.
    """
    actor_id = user.get("email") or user.get("uid", "caseworker")
    res = record_recommendation_decision(rid=rid, decision=req.decision, note=req.note or "", actor_id=actor_id)
    if not res:
        raise HTTPException(status_code=404, detail="Recommendation not found")
    return res
