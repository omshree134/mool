import numpy as np
from typing import List, Dict, Any, Tuple


def compute_ewma(xs: List[float], a: float = 0.3) -> List[float]:
    """Exponentially Weighted Moving Average (EWMA) smoothing."""
    if not xs:
        return []
    out = []
    s = xs[0]
    for x in xs:
        s = a * x + (1.0 - a) * s
        out.append(round(s, 2))
    return out


def compute_cusum_drift(xs: List[float], mu: float, sd: float, k: float = 0.5, h: float = 4.0) -> Tuple[bool, float]:
    """
    Cumulative Sum (CUSUM) test for sustained upward distress drift.
    Returns: (drift_detected, cumulative_sum)
    """
    if not xs:
        return False, 0.0

    s = 0.0
    safe_sd = max(sd, 1e-4)
    for x in xs:
        s = max(0.0, s + (x - mu) / safe_sd - k)
        if s > h:
            return True, round(s, 2)
    return False, round(s, 2)


def compute_trajectory_trends(history_scores: List[float]) -> Dict[str, Any]:
    """
    Calculates smoothed trajectory, slopes, and drift indicators:
    - current_score
    - smoothed_score
    - slope_7d: rate of score change over last 7 entries
    - slope_14d: rate of score change over last 14 entries
    - variability: standard deviation
    - cusum_drift: sustained upward trend signal
    """
    if not history_scores:
        return {
            "current_score": 30.0,
            "smoothed_score": 30.0,
            "slope_7d": 0.0,
            "slope_14d": 0.0,
            "variability": 0.0,
            "cusum_drift": False,
        }

    smoothed = compute_ewma(history_scores, a=0.3)
    curr = history_scores[-1]
    smooth_curr = smoothed[-1]

    # Calculate 7-day and 14-day slopes
    slope_7d = 0.0
    if len(history_scores) >= 2:
        window_7 = history_scores[-min(7, len(history_scores)):]
        x = np.arange(len(window_7))
        p = np.polyfit(x, window_7, 1)
        slope_7d = round(float(p[0]), 2)

    slope_14d = 0.0
    if len(history_scores) >= 5:
        window_14 = history_scores[-min(14, len(history_scores)):]
        x = np.arange(len(window_14))
        p = np.polyfit(x, window_14, 1)
        slope_14d = round(float(p[0]), 2)

    mean_val = float(np.mean(history_scores))
    std_val = float(np.std(history_scores))
    has_drift, cusum_stat = compute_cusum_drift(history_scores[-min(14, len(history_scores)):], mean_val, std_val)

    return {
        "current_score": round(curr, 1),
        "smoothed_score": round(smooth_curr, 1),
        "slope_7d": slope_7d,
        "slope_14d": slope_14d,
        "variability": round(std_val, 2),
        "cusum_drift": has_drift,
        "cusum_value": cusum_stat,
    }
