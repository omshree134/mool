import math
from typing import Dict, List, Optional, Any
from pydantic import BaseModel, Field

# Base weights across modalities
BASE_WEIGHTS = {
    "self_report": 0.50,
    "behaviour": 0.20,
    "language": 0.20,
    "voice": 0.10,
}

# Tier thresholds
T_WATCH = 40.0
T_OUTREACH = 60.0
T_URGENT = 80.0
HYSTERESIS = 5.0
CONTEXT_MAX_POINTS = 20.0


class DistressInputs(BaseModel):
    bid: str
    self_report: Optional[float] = Field(None, ge=0.0, le=100.0)
    behaviour: Optional[float] = Field(None, ge=0.0, le=100.0)
    language: Optional[float] = Field(None, ge=0.0, le=100.0)
    voice: Optional[float] = Field(None, ge=0.0, le=100.0)

    # Contextual triggers (Atrocity / judicial lifecycle)
    next_hearing_days: Optional[int] = None
    intimidation_hours_ago: Optional[float] = None
    compensation_overdue_days: Optional[int] = None
    accused_granted_bail: bool = False
    days_since_last_contact: int = 0

    # Historical state for anti-flicker hysteresis
    previous_score: Optional[float] = None
    previous_tier: Optional[str] = None

    # Immediate safety overrides
    explicit_crisis_flag: bool = False
    crisis_reason: Optional[str] = None


class DistressScoreResult(BaseModel):
    score: float
    tier: str
    components: Dict[str, Optional[float]]
    drivers: List[str]
    outreach_due: bool = False
    outreach_reason: Optional[str] = None
    is_crisis: bool = False


class ScoringEngine:
    @staticmethod
    def compute(inp: DistressInputs) -> DistressScoreResult:
        drivers: List[str] = []

        # ── 1. Immediate Safety Overrides ──────────────────────────────────────
        if inp.explicit_crisis_flag:
            reason = inp.crisis_reason or "Explicit distress or thoughts of self-harm disclosed."
            return DistressScoreResult(
                score=100.0,
                tier="crisis",
                components={
                    "self_report": inp.self_report or 100.0,
                    "behaviour": inp.behaviour,
                    "language": inp.language,
                    "voice": inp.voice,
                },
                drivers=[f"CRISIS SAFETY OVERRIDE: {reason}"],
                outreach_due=True,
                outreach_reason="Crisis trigger requires immediate intervention.",
                is_crisis=True,
            )

        # ── 2. Dynamic Component Combination ──────────────────────────────────
        active_components = {
            "self_report": inp.self_report,
            "behaviour": inp.behaviour,
            "language": inp.language,
            "voice": inp.voice,
        }
        available = {k: v for k, v in active_components.items() if v is not None}

        if available:
            total_avail_weight = sum(BASE_WEIGHTS[k] for k in available)
            base_score = sum(BASE_WEIGHTS[k] * v for k, v in available.items()) / total_avail_weight
        else:
            base_score = 30.0  # Baseline neutral when no recent modalities exist

        # Log driver explanations
        if inp.self_report is not None and inp.self_report >= 60.0:
            drivers.append(f"Elevated self-report check-in ({inp.self_report:.1f}/100)")
        if inp.behaviour is not None and inp.behaviour >= 60.0:
            drivers.append(f"Significant drop in daily mobility/activity baseline ({inp.behaviour:.1f}/100)")
        if inp.language is not None and inp.language >= 60.0:
            drivers.append(f"Heightened stress or fear detected in written notes ({inp.language:.1f}/100)")
        if inp.voice is not None and inp.voice >= 60.0:
            drivers.append(f"Elevated vocal acoustic stress via openSMILE ({inp.voice:.1f}/100)")

        # ── 3. Contextual Judicial & Safety Modifiers ─────────────────────────
        context_pts = 0.0

        if inp.intimidation_hours_ago is not None and inp.intimidation_hours_ago <= 72.0:
            pts = 15.0 if inp.intimidation_hours_ago <= 24.0 else 10.0
            context_pts += pts
            drivers.append(f"Recent threat/intimidation reported ({inp.intimidation_hours_ago:.0f}h ago) (+{pts:.0f} pts)")

        if inp.accused_granted_bail:
            context_pts += 15.0
            drivers.append("High-risk event: Accused granted bail or released (+15 pts)")

        if inp.next_hearing_days is not None and 0 <= inp.next_hearing_days <= 7:
            pts = 10.0 if inp.next_hearing_days <= 3 else 6.0
            context_pts += pts
            drivers.append(f"Special Court hearing scheduled in {inp.next_hearing_days} days (+{pts:.0f} pts)")

        if inp.compensation_overdue_days is not None and inp.compensation_overdue_days > 7:
            pts = min(10.0, 4.0 + (inp.compensation_overdue_days // 7) * 2.0)
            context_pts += pts
            drivers.append(f"Statutory relief payment overdue by {inp.compensation_overdue_days} days (+{pts:.0f} pts)")

        context_modifier = min(CONTEXT_MAX_POINTS, context_pts)
        final_score = min(100.0, max(0.0, base_score + context_modifier))

        # ── 4. Silence Detection (Treat Silence as an Active Signal) ──────────
        outreach_due = False
        outreach_reason = None

        hearing_near = inp.next_hearing_days is not None and inp.next_hearing_days <= 7
        silence_threshold = 3 if hearing_near else 5

        if inp.days_since_last_contact >= silence_threshold:
            outreach_due = True
            outreach_reason = (
                f"No check-in or contact for {inp.days_since_last_contact} days near scheduled hearing. Automated IVRS outreach scheduled."
                if hearing_near
                else f"No check-in or contact for {inp.days_since_last_contact} days. Automated IVRS outreach scheduled."
            )
            drivers.append(f"SILENCE SIGNAL: {outreach_reason}")

        # ── 5. Tier Assignment with Anti-Flicker Hysteresis ───────────────────
        if final_score >= T_URGENT:
            assigned_tier = "urgent"
        elif final_score >= T_OUTREACH:
            assigned_tier = "outreach"
        elif final_score >= T_WATCH:
            assigned_tier = "watch"
        else:
            assigned_tier = "stable"

        # Apply hysteresis to avoid flickering on boundaries
        if inp.previous_tier and inp.previous_score is not None:
            if inp.previous_tier == "urgent" and final_score >= (T_URGENT - HYSTERESIS):
                assigned_tier = "urgent"
            elif inp.previous_tier == "outreach" and final_score >= (T_OUTREACH - HYSTERESIS):
                assigned_tier = "outreach"
            elif inp.previous_tier == "watch" and final_score >= (T_WATCH - HYSTERESIS):
                assigned_tier = "watch"

        return DistressScoreResult(
            score=round(final_score, 1),
            tier=assigned_tier,
            components=active_components,
            drivers=drivers,
            outreach_due=outreach_due,
            outreach_reason=outreach_reason,
            is_crisis=False,
        )
