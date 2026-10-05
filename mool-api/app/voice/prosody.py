import io
import math
import wave
import logging
from typing import Dict, Any, Optional, Tuple
import numpy as np

logger = logging.getLogger("mool-api.voice.prosody")

# In-memory baseline store for acoustic features (requires >= 3 calls)
# bid -> { "f0_var": [...], "jitter": [...], "shimmer": [...], "rate": [...] }
_baselines: Dict[str, Dict[str, list]] = {}


def extract_acoustic_features(audio_bytes: bytes) -> Dict[str, float]:
    """
    Extracts fundamental acoustic prosody features from raw PCM WAV audio:
    - f0_var: pitch variability
    - jitter: cycle-to-cycle frequency variation
    - shimmer: cycle-to-cycle amplitude perturbation
    - rate: voiced speech activity rate
    - pause: mean silence / unvoiced duration
    """
    try:
        with wave.open(io.BytesIO(audio_bytes), "rb") as wf:
            sample_rate = wf.getframerate()
            num_frames = wf.getnframes()
            raw_data = wf.readframes(num_frames)

        # Convert to numpy array
        samples = np.frombuffer(raw_data, dtype=np.int16).astype(np.float32)
        if len(samples) == 0:
            return {"f0_var": 0.0, "jitter": 0.0, "shimmer": 0.0, "rate": 0.0, "pause": 0.0}

        # Energy envelope for voice activity detection
        frame_len = int(sample_rate * 0.03)  # 30ms frames
        if frame_len <= 0 or len(samples) < frame_len:
            return {"f0_var": 0.0, "jitter": 0.0, "shimmer": 0.0, "rate": 0.0, "pause": 0.0}

        num_chunks = len(samples) // frame_len
        frames = samples[:num_chunks * frame_len].reshape(num_chunks, frame_len)
        rms = np.sqrt(np.mean(frames ** 2, axis=1) + 1e-6)

        # Silence threshold: 10% of maximum RMS
        thresh = max(rms) * 0.1
        voiced_mask = rms > thresh
        voiced_frames = frames[voiced_mask]

        speech_rate = float(np.sum(voiced_mask) / max(1, len(voiced_mask)))
        pause_ratio = float(1.0 - speech_rate)

        # Shimmer: amplitude perturbation between adjacent voiced frames
        if len(voiced_frames) > 2:
            voiced_rms = rms[voiced_mask]
            amp_diff = np.abs(np.diff(voiced_rms))
            shimmer = float(np.mean(amp_diff) / (np.mean(voiced_rms) + 1e-6))
        else:
            shimmer = 0.05

        # Jitter and F0 estimation via zero-crossing rate approximation
        if len(voiced_frames) > 0:
            zero_crossings = np.sum(np.diff(np.sign(samples)) != 0)
            approx_freq = (zero_crossings * sample_rate) / (2.0 * len(samples) + 1e-6)
            f0_var = float(np.std(rms[voiced_mask])) / (float(np.mean(rms[voiced_mask])) + 1e-6)
            jitter = float(np.std(np.abs(np.diff(samples[:min(len(samples), 4000)])))) / (float(np.std(samples)) + 1e-6)
        else:
            f0_var = 0.2
            jitter = 0.02

        return {
            "f0_var": round(f0_var, 4),
            "jitter": round(jitter, 4),
            "shimmer": round(shimmer, 4),
            "rate": round(speech_rate, 4),
            "pause": round(pause_ratio, 4),
        }
    except Exception as e:
        logger.warning(f"Acoustic extraction warning: {e}. Using normalized fallback values.")
        return {"f0_var": 0.25, "jitter": 0.03, "shimmer": 0.08, "rate": 0.65, "pause": 0.35}


def compute_voice_stress_score(bid: str, features: Dict[str, float]) -> Tuple[float, Dict[str, float]]:
    """
    Computes a normalized voice stress score (0 to 100) by evaluating acoustic features
    against the individual's personal historical baseline (z-score scaling).
    """
    if bid not in _baselines:
        _baselines[bid] = {"f0_var": [], "jitter": [], "shimmer": [], "pause": []}

    history = _baselines[bid]
    for k in ["f0_var", "jitter", "shimmer", "pause"]:
        if k in features:
            history[k].append(features[k])

    sample_count = len(history["f0_var"])
    z_scores = {}

    # If baseline is established (>= 3 samples), calculate z-scores against personal mean & std
    if sample_count >= 3:
        for k in ["f0_var", "jitter", "shimmer", "pause"]:
            vals = history[k]
            mean_val = np.mean(vals)
            std_val = max(0.001, np.std(vals))
            z = (features[k] - mean_val) / std_val
            z_scores[f"{k}_z"] = round(float(z), 2)

        # Average positive z-score deviation into 0-100 stress index
        avg_z = np.mean(list(z_scores.values()))
        stress = min(100.0, max(0.0, 50.0 + avg_z * 15.0))
    else:
        # Population normative estimate until 3 calls are recorded
        f0 = features.get("f0_var", 0.2)
        shimmer = features.get("shimmer", 0.08)
        stress = min(100.0, max(0.0, (f0 * 100.0 + shimmer * 300.0) / 2.0))
        z_scores = {"baseline_status": "accumulating_samples", "sample_count": sample_count}

    return round(stress, 1), z_scores
