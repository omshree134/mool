import os
import sys

# Ensure UTF-8 output on Windows
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)

def test_endpoints():
    print("Testing Root...")
    r = client.get("/")
    assert r.status_code == 200, f"Root failed: {r.status_code}"
    print("✓ Root OK:", r.json().get("service"))

    print("\nTesting Forecast Predict...")
    r = client.post("/forecast/predict", json={
        "current_score": 68.0,
        "smoothed_score": 65.0,
        "slope_7d": 2.1,
        "days_to_hearing": 3.0,
        "days_to_bail_hearing": 2.0,
        "voice_stress_last": 72.0,
        "emotion_fear_last": 0.65
    })
    assert r.status_code == 200, f"Forecast failed: {r.status_code}"
    data = r.json()
    print("✓ Forecast OK. Risk:", data["beneficiary_risk"]["risk_probability"])
    print("  Drivers:", data["beneficiary_risk"]["top_drivers"])

    print("\nTesting Aggregates...")
    r = client.get("/aggregates/summary")
    assert r.status_code == 200, f"Aggregates failed: {r.status_code}"
    print("✓ National Aggregates OK. Total:", r.json().get("total_beneficiaries"))

    print("\nTesting Cron Tick...")
    r = client.post("/cron/tick", headers={"x-cron-secret": "mool_cron_secret_tick_2026"})
    assert r.status_code == 200, f"Cron tick failed: {r.status_code}"
    print("✓ Cron Tick OK:", r.json().get("message"))

    print("\nTesting Ingest Observation...")
    r = client.post("/ingest", json={
        "bid": "BEN-LKO-001",
        "channel": "app",
        "kind": "checkin",
        "payload": {"sleep": 1, "anxiety": 3},
        "features": {"self_report": 65.0}
    })
    assert r.status_code == 200, f"Ingest failed: {r.status_code}"
    print("✓ Ingest OK. Tier:", r.json().get("score_result", {}).get("tier"))

    print("\nTesting Recommendations...")
    r = client.get("/recommendations")
    assert r.status_code == 200, f"Recommendations failed: {r.status_code}"
    print("✓ Recommendations OK. Count:", len(r.json()))

    print("\nALL BACKEND API TESTS PASSED!")

if __name__ == "__main__":
    test_endpoints()
