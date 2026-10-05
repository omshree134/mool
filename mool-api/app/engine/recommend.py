import os
import uuid
import yaml
import logging
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any

logger = logging.getLogger("mool-api.engine.recommend")

CONFIG_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "config", "interventions.yaml")

def load_interventions_config() -> list:
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                data = yaml.safe_load(f)
                return data.get("interventions", [])
        except Exception as e:
            logger.error(f"Error reading interventions.yaml: {e}")
    return []

_interventions = load_interventions_config()

# Store active recommendations and caseworker decisions
_active_recommendations: Dict[str, Dict[str, Any]] = {}


def generate_recommendations(bid: str, context: Dict[str, Any]) -> List[Dict[str, Any]]:
    """
    Evaluates YAML intervention rules against beneficiary judicial and emotional context.
    Returns structured recommendations for caseworker review.
    """
    results = []
    intimidation_ago = context.get("intimidation_hours_ago")
    hearing_in = context.get("next_hearing_days")
    compensation_overdue = context.get("compensation_overdue_days")
    crisis_flag = context.get("explicit_crisis_flag", False)
    self_report = context.get("self_report", 0.0)
    accused_bail = context.get("accused_granted_bail", False)

    for item in _interventions:
        item_id = item.get("id")
        should_trigger = False
        reason = ""

        if item_id == "witness_protection":
            if intimidation_ago is not None and intimidation_ago <= 48 and hearing_in is not None and hearing_in <= 7:
                should_trigger = True
                reason = f"Intimidation reported {intimidation_ago:.0f} hours ago; Special Court hearing in {hearing_in} days."

        elif item_id == "compensation_followup":
            if compensation_overdue is not None and compensation_overdue >= 7:
                should_trigger = True
                reason = f"Statutory relief instalment overdue by {compensation_overdue} days under Rule 12(4) of PoA Rules."

        elif item_id == "psychiatric_referral":
            if crisis_flag or (self_report is not None and self_report >= 75.0):
                should_trigger = True
                reason = "Severe distress indicators or positive screening for acute trauma."

        elif item_id == "in_camera_hearing":
            if accused_bail and hearing_in is not None and hearing_in <= 10:
                should_trigger = True
                reason = f"Accused released on bail; hearing scheduled in {hearing_in} days. Protection from visual contact recommended."

        if should_trigger:
            rid = f"rec_{uuid.uuid4().hex[:10]}"
            now_iso = datetime.now(timezone.utc).isoformat()
            record = {
                "rid": rid,
                "bid": bid,
                "intervention_id": item_id,
                "title": item.get("title", item_id.replace("_", " ").title()),
                "action": item.get("action", ""),
                "reason": reason,
                "owner": item.get("owner", "counsellor"),
                "status": "pending",  # pending | accepted | rejected | done
                "created_at": now_iso,
                "decision": None,
                "decision_note": "",
                "decision_at": None,
            }
            _active_recommendations[rid] = record
            results.append(record)

    return results


def record_recommendation_decision(rid: str, decision: str, note: str = "", actor_id: str = "caseworker") -> Optional[Dict[str, Any]]:
    """
    Records caseworker's Accept, Reject, or Done feedback.
    Stores human-in-the-loop decision records for system auditing and future model retraining.
    """
    rec = _active_recommendations.get(rid)
    if not rec:
        return None

    now_iso = datetime.now(timezone.utc).isoformat()
    rec["status"] = decision.lower()
    rec["decision"] = decision.lower()
    rec["decision_note"] = note
    rec["decision_at"] = now_iso
    rec["decided_by"] = actor_id

    logger.info(f"Caseworker {actor_id} recorded decision '{decision}' for recommendation {rid}.")
    return rec


def list_recommendations(bid: Optional[str] = None, status: Optional[str] = None) -> List[Dict[str, Any]]:
    """Lists recommendations filtered by beneficiary or status."""
    results = list(_active_recommendations.values())
    if bid:
        results = [r for r in results if r.get("bid") == bid]
    if status:
        results = [r for r in results if r.get("status") == status]
    return sorted(results, key=lambda r: r["created_at"], reverse=True)
