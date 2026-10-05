from fastapi import APIRouter, Depends
from typing import Dict, Any, Optional
from pydantic import BaseModel
from app.deps import current_user
from app.engine.forecast import predict_14d_distress

router = APIRouter(prefix="/forecast", tags=["forecast"])


class ForecastInput(BaseModel):
    current_score: float = 45.0
    smoothed_score: float = 42.0
    slope_7d: float = 0.5
    slope_14d: float = 0.3
    variability: float = 3.5
    days_to_hearing: float = 999.0
    days_to_bail_hearing: float = 999.0
    days_since_intimidation: float = 999.0
    compensation_overdue_days: float = 0.0
    missed_contacts_streak: int = 0
    voice_stress_last: float = 30.0
    emotion_fear_last: float = 0.10


@router.post("/predict")
async def predict_forecast(
    payload: ForecastInput,
    user: dict = Depends(current_user),
):
    """
    Predicts 14-day distress escalation probability and returns top-3 SHAP explainability drivers.
    If risk > 0.60, indicates an Anticipated Escalation alert.
    """
    res = predict_14d_distress(payload.model_dump())
    return {
        "status": "success",
        "beneficiary_risk": res,
    }
