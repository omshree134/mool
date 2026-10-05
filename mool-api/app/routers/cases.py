import uuid
import logging
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from ..deps import get_current_user

logger = logging.getLogger("mool-api.routers.cases")
router = APIRouter(prefix="", tags=["Case Lifecycle & PoA Integration"])

# In-memory case events store for local prototyping
_mock_case_events: Dict[str, List[Dict[str, Any]]] = {}

# Seed initial mock PoA government portal cases for demo
_mock_poa_database = [
    {
        "case_id": "POA-2026-UP-LKO-0089",
        "bid": "ben_priya_sharma_01",
        "fir_number": "FIR 142/2026 PS Gomti Nagar",
        "act_sections": ["Section 3(1)(r)", "Section 3(1)(s)", "Section 15A"],
        "investigating_officer": "DSP R. K. Singh",
        "special_court": "Special Court (SC/ST Act), Lucknow",
        "accused_name": "Virender Pratap & 2 others",
        "accused_in_custody": False,
        "accused_granted_bail": True,
        "bail_date": "2026-09-20",
        "next_hearing_date": "2026-09-28",
        "hearing_stage": "Examination of Complainant (PW-1)",
        "compensation": {
            "total_sanctioned": 425000,
            "stage_1_fir_paid": True,
            "stage_1_amount": 106250,
            "stage_2_chargesheet_paid": False,
            "stage_2_due_date": "2026-09-10",
            "stage_2_amount": 212500,
            "stage_3_trial_amount": 106250,
        },
        "witness_protection_status": "Application Pending",
    },
    {
        "case_id": "POA-2026-MH-PUN-0112",
        "bid": "ben_anil_kamble_02",
        "fir_number": "FIR 88/2026 PS Haveli",
        "act_sections": ["Section 3(1)(g)", "Section 3(2)(va)"],
        "investigating_officer": "ACP S. Patil",
        "special_court": "Sessions Court, Pune",
        "accused_name": "Ramesh Deshmukh",
        "accused_in_custody": True,
        "accused_granted_bail": False,
        "bail_date": None,
        "next_hearing_date": "2026-10-05",
        "hearing_stage": "Framing of Charges",
        "compensation": {
            "total_sanctioned": 300000,
            "stage_1_fir_paid": True,
            "stage_1_amount": 75000,
            "stage_2_chargesheet_paid": True,
            "stage_2_amount": 150000,
            "stage_3_trial_amount": 75000,
        },
        "witness_protection_status": "Police Escort Approved",
    }
]


class CaseEventCreate(BaseModel):
    bid: str
    event_type: str = Field(
        ...,
        description="hearing | bail | chargesheet | compensation_due | compensation_paid | intimidation"
    )
    title: str
    description: Optional[str] = ""
    event_date: Optional[str] = None
    source: str = "manual_entry"  # poa_portal | counsellor | police_report | manual_entry
    metadata: Dict[str, Any] = Field(default_factory=dict)


class CaseEventResponse(BaseModel):
    eid: str
    bid: str
    event_type: str
    title: str
    description: str
    event_date: str
    source: str
    metadata: Dict[str, Any]


@router.post("/cases/event", response_model=CaseEventResponse)
async def record_case_event(event: CaseEventCreate, user: dict = Depends(get_current_user)):
    """
    Records a judicial or security milestone event for a beneficiary.
    Bail grant and intimidation events directly feed the distress scoring context.
    """
    eid = f"evt_{uuid.uuid4().hex[:10]}"
    now_iso = datetime.now(timezone.utc).isoformat()
    evt_date = event.event_date or now_iso

    record = {
        "eid": eid,
        "bid": event.bid,
        "event_type": event.event_type,
        "title": event.title,
        "description": event.description or "",
        "event_date": evt_date,
        "source": event.source,
        "metadata": event.metadata,
        "created_at": now_iso,
    }

    if event.bid not in _mock_case_events:
        _mock_case_events[event.bid] = []
    _mock_case_events[event.bid].append(record)

    logger.info(f"Recorded case event {eid} ({event.event_type}) for {event.bid}")
    return CaseEventResponse(**record)


@router.get("/cases/{bid}/events", response_model=List[CaseEventResponse])
async def list_case_events(bid: str, user: dict = Depends(get_current_user)):
    """Returns the chronological audit list of judicial and safety milestones for a beneficiary."""
    return [CaseEventResponse(**e) for e in _mock_case_events.get(bid, [])]


@router.get("/mock-poa/cases")
async def get_mock_poa_cases(user: dict = Depends(get_current_user)):
    """
    Mock adapter representing the National Portal for SC/ST Prevention of Atrocities Act (NHAA).
    Simulates syncing trial dates, investigating officer submissions, bail decisions, and statutory DBT relief.
    """
    return {
        "source": "Integrated Portal for SC/ST (PoA) Act (Simulated / Demo Adapter)",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "total_cases": len(_mock_poa_database),
        "cases": _mock_poa_database,
    }
