import os
import sys
import json
import random
from datetime import datetime, timedelta, timezone

# Ensure project root is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.deps import get_firestore_client
from app.engine.recommend import generate_recommendations
from app.engine.aggregates import recompute_all_aggregates, compute_scope_aggregates

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data")
SEED_EXPORT_PATH = os.path.join(OUTPUT_DIR, "demo_seed_export.json")
USERS_EXPORT_PATH = os.path.join(OUTPUT_DIR, "demo_seed_users.json")

DISTRICTS = [
    {"state": "UP", "district": "UP-LKO", "name": "Lucknow", "count": 20},
    {"state": "UP", "district": "UP-VNS", "name": "Varanasi", "count": 10},
    {"state": "MH", "district": "MH-PUN", "name": "Pune", "count": 10},
]

DEMO_ROLES = [
    {
        "email": "counsellor@mool.org",
        "role": "counsellor",
        "state": "UP",
        "district": "UP-LKO",
        "name": "Dr. Sunita Verma",
        "description": "Lucknow District Psychosocial Counsellor",
    },
    {
        "email": "district_officer@mool.org",
        "role": "district_officer",
        "state": "UP",
        "district": "UP-LKO",
        "name": "Shri Rajesh Kumar, IAS",
        "description": "District Magistrate / PoA Nodal Officer (Lucknow)",
    },
    {
        "email": "state_officer@mool.org",
        "role": "state_officer",
        "state": "UP",
        "district": "*",
        "name": "Ms. Ananya Sharma, IPS",
        "description": "State SC/ST Protection Cell Coordinator (Uttar Pradesh)",
    },
    {
        "email": "national_officer@mool.org",
        "role": "national_officer",
        "state": "*",
        "district": "*",
        "name": "Joint Secretary (PoA Division)",
        "description": "Ministry of Social Justice & Empowerment, GoI",
    },
]


def generate_demo_dataset():
    random.seed(101)
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    beneficiaries = []
    cases = []
    alerts = []
    all_recommendations = []
    now = datetime.now(timezone.utc)

    # 1. Generate Beneficiaries & Cases
    idx = 1
    for dist_info in DISTRICTS:
        state_code = dist_info["state"]
        dist_code = dist_info["district"]
        dist_name = dist_info["name"]

        for i in range(1, dist_info["count"] + 1):
            bid = f"BEN-{dist_code.split('-')[1]}-{i:03d}"
            case_id = f"FIR-{state_code}-2026-{1000 + idx}"
            idx += 1

            # Distribute tiers realistically: mostly stable/watch, some outreach, few urgent, 1-2 crisis
            tier_weights = [0.45, 0.25, 0.18, 0.08, 0.04]
            tier = random.choices(["stable", "watch", "outreach", "urgent", "crisis"], weights=tier_weights)[0]

            if tier == "stable":
                score = round(random.uniform(15.0, 38.0), 1)
                days_to_hearing = random.randint(18, 60)
                days_to_bail = 999
                comp_overdue = 0
                days_since_intimidation = 999
            elif tier == "watch":
                score = round(random.uniform(40.0, 56.0), 1)
                days_to_hearing = random.randint(10, 25)
                days_to_bail = 999
                comp_overdue = random.choice([0, 14, 21])
                days_since_intimidation = 999
            elif tier == "outreach":
                score = round(random.uniform(60.0, 78.0), 1)
                days_to_hearing = random.randint(4, 12)
                days_to_bail = random.choice([4, 6, 999])
                comp_overdue = random.choice([25, 45, 60])
                days_since_intimidation = random.choice([5, 12, 999])
            elif tier == "urgent":
                score = round(random.uniform(80.0, 91.0), 1)
                days_to_hearing = random.randint(2, 5)
                days_to_bail = random.choice([1, 2, 3])
                comp_overdue = random.choice([45, 75])
                days_since_intimidation = random.choice([2, 4])
            else:  # crisis
                score = round(random.uniform(92.0, 99.0), 1)
                days_to_hearing = 1
                days_to_bail = 1
                comp_overdue = 60
                days_since_intimidation = 1

            lang = "mr" if state_code == "MH" else random.choice(["hi", "hi", "en"])
            phone = f"+9198765{random.randint(10000, 99999)}"

            b_data = {
                "id": bid,
                "beneficiaryId": bid,
                "caseId": case_id,
                "stateCode": state_code,
                "districtCode": dist_code,
                "districtName": dist_name,
                "preferredLanguage": lang,
                "phoneNumber": phone,
                "current_score": score,
                "current_tier": tier,
                "days_to_hearing": days_to_hearing,
                "days_to_bail_hearing": days_to_bail,
                "days_since_intimidation": days_since_intimidation,
                "compensation_overdue_days": comp_overdue,
                "assigned_counsellor_id": f"counsellor_{dist_code.lower()}",
                "updated_at": (now - timedelta(hours=random.randint(1, 48))).isoformat(),
            }
            beneficiaries.append(b_data)

            # Generate Case Document
            c_data = {
                "id": case_id,
                "caseId": case_id,
                "beneficiaryId": bid,
                "firNumber": f"FIR/{dist_name.upper()}/{2026}/{100 + i}",
                "court": f"Special Court (SC/ST PoA Act), {dist_name}",
                "sections": ["Section 3(1)(r)", "Section 3(1)(s)", "Section 3(2)(va)"],
                "hearing_date": (now + timedelta(days=days_to_hearing)).strftime("%Y-%m-%d"),
                "bail_hearing_date": (now + timedelta(days=days_to_bail)).strftime("%Y-%m-%d") if days_to_bail < 900 else None,
                "compensation_sanctioned": comp_overdue > 0 or random.random() < 0.7,
                "compensation_disbursed": comp_overdue == 0,
                "intimidation_reported": days_since_intimidation < 900,
                "stateCode": state_code,
                "districtCode": dist_code,
            }
            cases.append(c_data)

            # Generate Active Alert if tier is outreach, urgent, or crisis
            if tier in ["outreach", "urgent", "crisis"]:
                aid = f"ALT-{dist_code.split('-')[1]}-{i:03d}"
                elapsed_min = random.randint(10, 180)
                sla_deadline_h = 24 if tier == "outreach" else (4 if tier == "urgent" else 0.25)
                sla_time = now - timedelta(minutes=elapsed_min) + timedelta(hours=sla_deadline_h)

                reasons = []
                if days_to_bail <= 3:
                    reasons.append(f"Imminent bail hearing in {days_to_bail} days")
                if days_to_hearing <= 5:
                    reasons.append(f"Special court trial hearing in {days_to_hearing} days")
                if days_since_intimidation < 10:
                    reasons.append(f"Witness intimidation reported {days_since_intimidation} days ago")
                if comp_overdue > 30:
                    reasons.append(f"Victim compensation delayed by {comp_overdue} days")
                if not reasons:
                    reasons.append(f"High multi-channel distress score ({score}/100)")

                alert_doc = {
                    "id": aid,
                    "alert_id": aid,
                    "beneficiary_id": bid,
                    "case_id": case_id,
                    "stateCode": state_code,
                    "districtCode": dist_code,
                    "tier": tier,
                    "score": score,
                    "reasons": reasons,
                    "current_handler_role": "counsellor" if tier in ["watch", "outreach"] else ("district_officer" if tier == "urgent" else "crisis_team"),
                    "created_at": (now - timedelta(minutes=elapsed_min)).isoformat(),
                    "sla_deadline": sla_time.isoformat(),
                    "acknowledged": False,
                    "escalation_count": 1 if elapsed_min > (sla_deadline_h * 60) else 0,
                }
                alerts.append(alert_doc)

                # Generate Explainable Recommendations for this alert
                recs = generate_recommendations(
                    bid=bid,
                    context={
                        "intimidation_hours_ago": days_since_intimidation * 24 if days_since_intimidation < 900 else None,
                        "next_hearing_days": days_to_hearing,
                        "compensation_overdue_days": comp_overdue,
                        "explicit_crisis_flag": tier == "crisis",
                        "self_report": score,
                        "accused_bail": days_to_bail <= 3,
                    },
                )
                for r in recs:
                    r["stateCode"] = state_code
                    r["districtCode"] = dist_code
                    all_recommendations.append(r)

    print(f"Generated {len(beneficiaries)} beneficiaries, {len(cases)} cases, {len(alerts)} alerts, and {len(all_recommendations)} recommendations.")

    # 2. Write to Firestore if connected, else export local demo JSON
    db = get_firestore_client()
    if db:
        print("Uploading seed dataset to Firestore...")
        batch = db.batch()
        count = 0

        for b in beneficiaries:
            ref = db.collection("beneficiaries").document(b["id"])
            batch.set(ref, b)
            count += 1
            if count % 450 == 0:
                batch.commit()
                batch = db.batch()

        for c in cases:
            ref = db.collection("cases").document(c["id"])
            batch.set(ref, c)
            count += 1
            if count % 450 == 0:
                batch.commit()
                batch = db.batch()

        for a in alerts:
            ref = db.collection("alerts").document(a["id"])
            batch.set(ref, a)
            count += 1
            if count % 450 == 0:
                batch.commit()
                batch = db.batch()

        for r in all_recommendations:
            ref = db.collection("recommendations").document(r["recommendation_id"])
            batch.set(ref, r)
            count += 1
            if count % 450 == 0:
                batch.commit()
                batch = db.batch()

        batch.commit()
        print("Firestore seed upload completed!")

        # Recompute rollups
        print("Recomputing aggregate rollups...")
        recompute_all_aggregates()
    else:
        print("Firestore client not configured; creating local demo seed file.")

    # Export demo snapshot for offline/local development
    demo_export = {
        "generated_at": now.isoformat(),
        "beneficiaries": beneficiaries,
        "cases": cases,
        "alerts": alerts,
        "recommendations": all_recommendations,
        "aggregates": {
            "national": compute_scope_aggregates(beneficiaries, alerts),
            "state_UP": compute_scope_aggregates(
                [b for b in beneficiaries if b["stateCode"] == "UP"],
                [a for a in alerts if a["stateCode"] == "UP"],
            ),
            "state_MH": compute_scope_aggregates(
                [b for b in beneficiaries if b["stateCode"] == "MH"],
                [a for a in alerts if a["stateCode"] == "MH"],
            ),
            "district_UP-LKO": compute_scope_aggregates(
                [b for b in beneficiaries if b["districtCode"] == "UP-LKO"],
                [a for a in alerts if a["districtCode"] == "UP-LKO"],
            ),
        },
    }

    with open(SEED_EXPORT_PATH, "w", encoding="utf-8") as f:
        json.dump(demo_export, f, indent=2)
    print(f"Saved local demo snapshot to {SEED_EXPORT_PATH}")

    with open(USERS_EXPORT_PATH, "w", encoding="utf-8") as f:
        json.dump(DEMO_ROLES, f, indent=2)
    print(f"Saved demo role accounts to {USERS_EXPORT_PATH}")


if __name__ == "__main__":
    generate_demo_dataset()
