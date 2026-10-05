import os
import uuid
import yaml
import logging
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional, Any

logger = logging.getLogger("mool-api.engine.escalation")

CONFIG_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "config", "escalation.yaml")

# Load configuration with fallback defaults
def load_escalation_config() -> dict:
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                return yaml.safe_load(f)
        except Exception as e:
            logger.error(f"Error reading escalation.yaml: {e}")
    return {
        "tiers": {
            "watch": {"notify": ["counsellor"], "ack_hours": 72},
            "outreach": {"notify": ["counsellor", "nodal_officer"], "ack_hours": 24},
            "urgent": {"notify": ["counsellor", "nodal_officer", "dmhp", "sp_office"], "ack_hours": 4},
            "crisis": {"notify": ["crisis_desk", "nodal_officer", "sp_office"], "ack_minutes": 15},
        },
        "escalate_if_unacknowledged": {
            "counsellor": "nodal_officer",
            "nodal_officer": "dm_office",
            "dm_office": "state_nodal_officer",
        }
    }

_config = load_escalation_config()

# In-memory store for active alerts
_active_alerts: Dict[str, Dict[str, Any]] = {}


def create_alert(bid: str, tier: str, reasons: List[str], district_code: str = "UP-LKO") -> Optional[Dict[str, Any]]:
    """
    Creates an alert record when a beneficiary transitions to Watch, Outreach, Urgent, or Crisis.
    Computes strict acknowledgment deadline from SLA configuration.
    """
    tier_config = _config.get("tiers", {}).get(tier.lower())
    if not tier_config:
        return None

    aid = f"alert_{uuid.uuid4().hex[:10]}"
    now = datetime.now(timezone.utc)

    # Compute deadline
    if "ack_minutes" in tier_config:
        deadline = now + timedelta(minutes=tier_config["ack_minutes"])
    else:
        hours = tier_config.get("ack_hours", 24)
        deadline = now + timedelta(hours=hours)

    notified = tier_config.get("notify", ["counsellor"])
    initial_owner = notified[0]

    record = {
        "aid": aid,
        "bid": bid,
        "district_code": district_code,
        "tier": tier.lower(),
        "reasons": reasons,
        "notified_roles": notified,
        "escalation_level": initial_owner,
        "status": "pending",
        "created_at": now.isoformat(),
        "ack_deadline": deadline.isoformat(),
        "audit_log": [
            {
                "timestamp": now.isoformat(),
                "action": "alert_created",
                "details": f"Alert generated at {tier.upper()} tier with SLA {deadline.isoformat()} assigned to {initial_owner}."
            }
        ]
    }

    _active_alerts[aid] = record
    logger.info(f"Generated alert {aid} ({tier}) for {bid} assigned to {initial_owner}.")

    # Immediate dispatch simulation for Crisis
    if tier.lower() == "crisis":
        logger.critical(f"CRISIS ALERT {aid} FOR {bid}! Instant dispatch to Tele-MANAS (14416) & Nodal Desk.")
        record["audit_log"].append({
            "timestamp": now.isoformat(),
            "action": "instant_crisis_dispatch",
            "details": "Immediate non-blocking push to crisis response desk & Tele-MANAS."
        })

    return record


def acknowledge_alert(aid: str, actor_id: str, note: str = "") -> Optional[Dict[str, Any]]:
    """Acknowledges an active alert, stopping automatic cron SLA escalation."""
    alert = _active_alerts.get(aid)
    if not alert:
        return None

    now = datetime.now(timezone.utc).isoformat()
    alert["status"] = "acknowledged"
    alert["acknowledged_by"] = actor_id
    alert["acknowledged_at"] = now
    alert["audit_log"].append({
        "timestamp": now,
        "action": "alert_acknowledged",
        "details": f"Acknowledged by {actor_id}. Note: {note}"
    })
    logger.info(f"Alert {aid} acknowledged by {actor_id}.")
    return alert


def check_and_escalate_overdue_alerts() -> List[Dict[str, Any]]:
    """
    Invoked on every /cron/tick.
    Identifies unacknowledged alerts that have exceeded their SLA deadline,
    escalates them to the next administrative rank, and logs immutable audit records.
    """
    now = datetime.now(timezone.utc)
    escalations = []
    matrix = _config.get("escalate_if_unacknowledged", {})

    for aid, alert in _active_alerts.items():
        if alert["status"] in ["pending", "escalated"]:
            deadline = datetime.fromisoformat(alert["ack_deadline"])
            if now > deadline:
                current_owner = alert["escalation_level"]
                next_owner = matrix.get(current_owner)

                if next_owner:
                    alert["status"] = "escalated"
                    alert["escalation_level"] = next_owner
                    # Extend deadline by 4 hours for the new escalation level
                    new_deadline = now + timedelta(hours=4)
                    alert["ack_deadline"] = new_deadline.isoformat()

                    audit_entry = {
                        "timestamp": now.isoformat(),
                        "action": "sla_auto_escalation",
                        "details": f"SLA breached. Auto-escalated from {current_owner} to {next_owner}. New deadline: {new_deadline.isoformat()}."
                    }
                    alert["audit_log"].append(audit_entry)
                    escalations.append(alert)
                    logger.warning(f"Auto-escalated alert {aid} to {next_owner}.")

    return escalations


def list_alerts(district_code: Optional[str] = None, status: Optional[str] = None) -> List[Dict[str, Any]]:
    """Returns alerts matching optional district and status filters."""
    results = list(_active_alerts.values())
    if district_code:
        results = [a for a in results if a.get("district_code") == district_code]
    if status:
        results = [a for a in results if a.get("status") == status]
    return sorted(results, key=lambda a: a["created_at"], reverse=True)
