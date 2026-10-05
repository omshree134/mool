import os
import logging
from datetime import datetime, timezone
from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("mool-api.routers.cron")
router = APIRouter(prefix="/cron", tags=["Scheduled Tasks & Keep-Alive"])


class CronResponse(BaseModel):
    status: str
    timestamp: str
    message: str


@router.post("/tick", response_model=CronResponse)
async def cron_tick(x_cron_secret: str = Header(None)):
    """
    Heartbeat and background tasks endpoint.
    Called every 10 minutes by cron-job.org to keep Hugging Face Space awake,
    preventing Twilio IVRS cold-start timeouts and later running SLA auto-escalations.
    """
    expected_secret = os.getenv("CRON_SECRET", "mool_cron_secret_tick_2026")
    if not x_cron_secret or x_cron_secret != expected_secret:
        raise HTTPException(status_code=403, detail="Invalid cron secret header")

    now_iso = datetime.now(timezone.utc).isoformat()
    logger.info(f"Cron heartbeat tick received at {now_iso}.")

    from ..engine.escalation import check_and_escalate_overdue_alerts
    from ..engine.aggregates import recompute_all_aggregates
    escalated = check_and_escalate_overdue_alerts()
    agg_res = recompute_all_aggregates()
    msg = f"Keep-alive tick processed. {len(escalated)} alerts escalated. Aggregates recomputed ({agg_res.get('status')})."

    return CronResponse(
        status="ok",
        timestamp=now_iso,
        message=msg
    )
