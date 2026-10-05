import os
import json
import logging
from typing import Dict, Any, List, Tuple
import numpy as np
import lightgbm as lgb

logger = logging.getLogger("mool.forecast")

MODEL_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "models", "forecast.lgb")
META_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "models", "forecast_meta.json")

FEATURE_ORDER = [
    "current_score",
    "smoothed_score",
    "slope_7d",
    "slope_14d",
    "variability",
    "days_to_hearing",
    "days_to_bail_hearing",
    "days_since_intimidation",
    "compensation_overdue_days",
    "missed_contacts_streak",
    "voice_stress_last",
    "emotion_fear_last",
]

_BOOSTER = None
_META = {}


def get_booster() -> lgb.Booster:
    global _BOOSTER, _META
    if _BOOSTER is None:
        if os.path.exists(MODEL_PATH):
            _BOOSTER = lgb.Booster(model_file=MODEL_PATH)
            logger.info("Loaded LightGBM forecast booster from %s", MODEL_PATH)
        else:
            logger.warning("Forecast model file %s does not exist yet. Run scripts/train_forecast.py", MODEL_PATH)
    if not _META and os.path.exists(META_PATH):
        try:
            with open(META_PATH, "r", encoding="utf-8") as f:
                _META = json.load(f)
        except Exception as e:
            logger.warning("Could not load forecast metadata: %s", e)
    return _BOOSTER


def format_driver(feature: str, shap_val: float, raw_val: float) -> str:
    sign = "+" if shap_val >= 0 else ""
    val_str = f"{sign}{shap_val:.2f}"

    if feature == "days_to_bail_hearing":
        return f"bail hearing in {int(raw_val)} days ({val_str})"
    elif feature == "days_to_hearing":
        return f"court hearing in {int(raw_val)} days ({val_str})"
    elif feature == "days_since_intimidation":
        if raw_val >= 900:
            return f"intimidation history ({val_str})"
        return f"intimidation reported {int(raw_val)} days ago ({val_str})"
    elif feature == "slope_7d":
        direction = "rising" if raw_val > 0 else "declining"
        return f"{direction} 7d trend ({val_str})"
    elif feature == "slope_14d":
        direction = "rising" if raw_val > 0 else "declining"
        return f"{direction} 14d trajectory ({val_str})"
    elif feature == "missed_contacts_streak":
        return f"{int(raw_val)} missed check-ins ({val_str})"
    elif feature == "voice_stress_last":
        return f"voice stress at {raw_val:.0f}/100 ({val_str})"
    elif feature == "emotion_fear_last":
        return f"fear signal {int(raw_val * 100)}% ({val_str})"
    elif feature == "compensation_overdue_days":
        return f"compensation overdue by {int(raw_val)} days ({val_str})"
    elif feature == "current_score":
        return f"current distress {raw_val:.0f}/100 ({val_str})"
    elif feature == "smoothed_score":
        return f"smoothed distress {raw_val:.0f}/100 ({val_str})"
    elif feature == "variability":
        return f"emotional volatility ±{raw_val:.1f} ({val_str})"
    return f"{feature} ({val_str})"


def predict_14d_distress(features: Dict[str, Any]) -> Dict[str, Any]:
    """
    Predicts the probability of beneficiary escalating to Urgent (score >= 80)
    in the next 14 days using LightGBM TreeSHAP.
    """
    booster = get_booster()
    if booster is None:
        # Fallback heuristic if model not loaded
        cur = float(features.get("current_score", 40.0))
        prob = min(0.95, max(0.05, (cur - 20) / 70.0))
        return {
            "risk_probability": round(prob, 2),
            "will_escalate_14d": prob >= 0.50,
            "drivers": ["Model fallback active: score based estimate"],
            "summary": f"Estimated risk {int(prob*100)}% based on current score {cur:.0f}",
            "anticipate_alert": prob >= 0.60,
        }

    # Vectorize features in exact order
    row = []
    for f in FEATURE_ORDER:
        val = features.get(f)
        if val is None:
            # Default to median or sensible constant
            default_val = _META.get("medians", {}).get(f, 0.0)
            val = default_val
        row.append(float(val))

    x = np.array([row], dtype=np.float32)

    # 1. Calibrated Probability
    prob = float(booster.predict(x)[0])

    # 2. Native TreeSHAP contributions
    contribs = booster.predict(x, pred_contrib=True)[0]  # shape: (num_features + 1,)
    feature_contribs = contribs[:-1]  # Exclude base margin

    # Rank features by positive contribution (risk pushers)
    indexed_contribs = list(zip(FEATURE_ORDER, feature_contribs, row))
    # Sort primarily by positive impact on risk
    sorted_drivers = sorted(indexed_contribs, key=lambda d: d[1], reverse=True)

    top_drivers = []
    for feat_name, shap_val, raw_v in sorted_drivers[:3]:
        top_drivers.append(format_driver(feat_name, float(shap_val), float(raw_v)))

    drivers_summary = ", ".join(top_drivers)
    risk_pct = int(round(prob * 100))
    summary_text = f"Risk {prob:.2f} in 14 days — main drivers: {drivers_summary}"

    return {
        "risk_probability": round(prob, 4),
        "will_escalate_14d": prob >= 0.50,
        "top_drivers": top_drivers,
        "summary": summary_text,
        "anticipate_alert": prob >= 0.60,
        "features_evaluated": dict(zip(FEATURE_ORDER, row)),
    }
