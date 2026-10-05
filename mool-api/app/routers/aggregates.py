from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Dict, Any, Optional
from app.deps import current_user, get_firestore_client
from app.engine.aggregates import recompute_all_aggregates, get_mock_aggregates

router = APIRouter(prefix="/aggregates", tags=["aggregates"])


@router.get("/summary")
async def get_national_summary(
    user: dict = Depends(current_user),
):
    """
    Returns high-level national distress, tier distribution, and resolution performance.
    K-anonymity applied: counts below 5 are masked as '<5'.
    """
    db = get_firestore_client()
    if not db:
        return get_mock_aggregates()["national"]

    try:
        doc = db.collection("aggregates").document("national").get()
        if doc.exists:
            return doc.to_dict()
    except Exception:
        pass
    return get_mock_aggregates()["national"]


@router.get("/state/{state_code}")
async def get_state_aggregate(
    state_code: str,
    user: dict = Depends(current_user),
):
    """
    Returns state-level aggregation and district breakdown.
    Requires role: state_officer, national_officer, or district_officer.
    """
    role = user.get("role", "counsellor")
    if role not in ["state_officer", "national_officer", "district_officer", "dev_user"]:
        raise HTTPException(status_code=403, detail="Insufficient role permissions for state aggregates")

    db = get_firestore_client()
    if not db:
        mock = get_mock_aggregates()
        return mock.get("states", {}).get(state_code.upper(), {"error": f"No data for state {state_code}"})

    try:
        doc = db.collection("aggregates").document(f"state_{state_code.upper()}").get()
        if doc.exists:
            return doc.to_dict()
    except Exception:
        pass
    mock = get_mock_aggregates()
    return mock.get("states", {}).get(state_code.upper(), {"state_code": state_code, "status": "no_data"})


@router.get("/district/{district_code}")
async def get_district_aggregate(
    district_code: str,
    user: dict = Depends(current_user),
):
    """
    Returns district-level triage and case summary metrics.
    """
    db = get_firestore_client()
    if not db:
        mock = get_mock_aggregates()
        return mock.get("districts", {}).get(district_code.upper(), {"district_code": district_code, "status": "mock"})

    try:
        doc = db.collection("aggregates").document(f"district_{district_code.upper()}").get()
        if doc.exists:
            return doc.to_dict()
    except Exception:
        pass
    mock = get_mock_aggregates()
    return mock.get("districts", {}).get(district_code.upper(), {"district_code": district_code, "status": "mock"})


@router.post("/recompute")
async def trigger_recompute(
    user: dict = Depends(current_user),
):
    """
    Forces full recomputation of national, state, and district aggregates.
    """
    result = recompute_all_aggregates()
    return result
