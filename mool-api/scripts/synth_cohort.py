import os
import csv
import random
import numpy as np

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data")
OUTPUT_PATH = os.path.join(OUTPUT_DIR, "synthetic_cohort.csv")


def generate_synthetic_cohort(num_beneficiaries: int = 1000, days: int = 180):
    """
    Simulates a longitudinal cohort of atrocity survivors responding to realistic trial milestones:
    - Hearings cause temporary acute spikes
    - Intimidation causes persistent distress elevation
    - Release of accused on bail causes sharp distress surges
    - Overdue compensation causes slow corrosive upward drift
    - High distress significantly increases probability of withdrawal/missed check-ins
    """
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    random.seed(42)
    np.random.seed(42)

    rows = []
    fieldnames = [
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
        "escalates_14d",  # Target: 1 if reaches Urgent (>=80) in next 14 days, else 0
    ]

    for b in range(num_beneficiaries):
        # 3 Cohorts: Mild (40%), Vulnerable (40%), High-Trauma/Acute (20%)
        cohort_type = random.choices(["mild", "vulnerable", "acute"], weights=[0.40, 0.40, 0.20])[0]
        if cohort_type == "mild":
            base_distress = np.random.uniform(20.0, 38.0)
        elif cohort_type == "vulnerable":
            base_distress = np.random.uniform(38.0, 58.0)
        else:
            base_distress = np.random.uniform(58.0, 72.0)

        current_latent = base_distress

        # Simulate scheduled events across 180 days
        hearing_schedule = sorted(random.sample(range(10, days), k=random.randint(2, 6)))
        bail_hearing = random.choice(range(15, 60)) if random.random() < 0.6 else 999
        intimidation_days = sorted(random.sample(range(5, days), k=random.randint(0, 5)))
        compensation_delay_start = random.choice(range(20, 100)) if random.random() < 0.55 else 999

        daily_scores = []
        missed_streak = 0
        lingering_shock = 0.0

        # First pass: simulate trajectory across all days
        for d in range(days):
            # Baseline daily variability
            daily_shock = np.random.normal(0, 1.5)

            # Proximity to court hearing (anticipatory anxiety)
            days_to_h = min([abs(h - d) for h in hearing_schedule if h >= d] or [999])
            if days_to_h <= 4:
                daily_shock += np.random.uniform(8.0, 18.0)

            # Proximity to bail hearing / release of accused (acute danger fear)
            days_to_bail = bail_hearing - d if bail_hearing >= d else 999
            if 0 <= days_to_bail <= 3:
                daily_shock += np.random.uniform(14.0, 26.0)

            # Intimidation threat occurrence (severe trauma spike that lingers)
            if d in intimidation_days:
                lingering_shock += np.random.uniform(22.0, 35.0)

            # Cumulative compensation delay
            comp_overdue = max(0, d - compensation_delay_start)
            comp_penalty = min(15.0, (comp_overdue // 7) * 2.5) if comp_overdue > 0 else 0.0

            # Autoregressive trauma model: shocks linger and decay slowly over 7-10 days
            lingering_shock *= 0.82
            current_latent = (
                0.78 * current_latent
                + 0.22 * base_distress
                + daily_shock
                + lingering_shock
                + comp_penalty * 0.1
            )
            current_latent = np.clip(current_latent, 10.0, 100.0)
            daily_scores.append(round(current_latent, 1))

        # Second pass: sample rows and extract features and forward-looking labels
        missed_streak = 0
        for d in range(days):
            current_latent = daily_scores[d]
            miss_prob = 0.06 if current_latent < 45 else (0.22 if current_latent < 68 else 0.52)
            if random.random() < miss_prob:
                missed_streak += 1
            else:
                missed_streak = 0

            if 20 <= d <= (days - 15) and random.random() < 0.18:
                window_scores = daily_scores[max(0, d - 14): d + 1]
                smoothed = np.mean(window_scores[-5:])
                slope_7 = (window_scores[-1] - window_scores[-min(7, len(window_scores))]) / 7.0
                slope_14 = (window_scores[-1] - window_scores[0]) / len(window_scores)
                var = np.std(window_scores)

                days_to_h = min([abs(h - d) for h in hearing_schedule if h >= d] or [999])
                days_to_bail = bail_hearing - d if bail_hearing >= d else 999
                recent_intimidation = [d - i for i in intimidation_days if 0 <= (d - i) <= 14]
                days_since_intimidation = min(recent_intimidation) if recent_intimidation else 999
                comp_overdue = max(0, d - compensation_delay_start)

                # Future label: does score reach >= 80 (Urgent) in the next 14 days?
                future_14d = daily_scores[d + 1: d + 15]
                escalates = 1 if any(s >= 80.0 for s in future_14d) else 0

                voice_stress = min(100.0, max(0.0, current_latent + np.random.normal(0, 8.0)))
                emotion_fear = min(1.0, max(0.0, (current_latent / 100.0) + np.random.normal(0, 0.1)))

                rows.append({
                    "current_score": round(current_latent, 1),
                    "smoothed_score": round(smoothed, 1),
                    "slope_7d": round(slope_7, 2),
                    "slope_14d": round(slope_14, 2),
                    "variability": round(var, 2),
                    "days_to_hearing": days_to_h,
                    "days_to_bail_hearing": days_to_bail,
                    "days_since_intimidation": days_since_intimidation,
                    "compensation_overdue_days": comp_overdue,
                    "missed_contacts_streak": missed_streak,
                    "voice_stress_last": round(voice_stress, 1),
                    "emotion_fear_last": round(emotion_fear, 2),
                    "escalates_14d": escalates,
                })

    with open(OUTPUT_PATH, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Generated {len(rows)} longitudinal samples across {num_beneficiaries} survivors in {OUTPUT_PATH}")
    positive_rate = sum(r["escalates_14d"] for r in rows) / len(rows)
    print(f"Positive 14-day escalation rate: {positive_rate * 100:.1f}%")


if __name__ == "__main__":
    generate_synthetic_cohort()
