import os
import json
import pandas as pd
import numpy as np
import lightgbm as lgb
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score, classification_report, accuracy_score

DATA_PATH = os.path.join(os.path.dirname(__file__), "..", "data", "synthetic_cohort.csv")
MODELS_DIR = os.path.join(os.path.dirname(__file__), "..", "models")
MODEL_PATH = os.path.join(MODELS_DIR, "forecast.lgb")
META_PATH = os.path.join(MODELS_DIR, "forecast_meta.json")


def train_distress_forecast():
    os.makedirs(MODELS_DIR, exist_ok=True)
    if not os.path.exists(DATA_PATH):
        raise FileNotFoundError(f"Synthetic cohort data not found at {DATA_PATH}. Run scripts/synth_cohort.py first.")

    df = pd.read_csv(DATA_PATH)
    print(f"Loaded {len(df)} samples from {DATA_PATH}")

    feature_cols = [
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
    target_col = "escalates_14d"

    X = df[feature_cols]
    y = df[target_col]

    X_train, X_val, y_train, y_val = train_test_split(
        X, y, test_size=0.20, random_state=42, stratify=y
    )

    print(f"Training set: {len(X_train)} samples, Validation set: {len(X_val)} samples")

    # LightGBM Classifier with conservative hyperparameters to avoid overfitting
    clf = lgb.LGBMClassifier(
        objective="binary",
        boosting_type="gbdt",
        n_estimators=120,
        learning_rate=0.05,
        max_depth=5,
        num_leaves=31,
        min_child_samples=20,
        subsample=0.85,
        colsample_bytree=0.85,
        random_state=42,
        verbosity=-1,
    )

    clf.fit(
        X_train,
        y_train,
        eval_set=[(X_val, y_val)],
        callbacks=[lgb.early_stopping(stopping_rounds=15, verbose=False)],
    )

    y_pred_proba = clf.predict_proba(X_val)[:, 1]
    y_pred = (y_pred_proba >= 0.50).astype(int)

    auc = roc_auc_score(y_val, y_pred_proba)
    acc = accuracy_score(y_val, y_pred)
    print(f"\n--- Validation Performance ---")
    print(f"ROC-AUC: {auc:.4f}")
    print(f"Accuracy: {acc:.4f}")
    print("\nClassification Report:")
    print(classification_report(y_val, y_pred, target_names=["Stable", "Escalates (>=80)"]))

    # Save booster to models/forecast.lgb
    booster = clf.booster_
    booster.save_model(MODEL_PATH)
    file_size_kb = os.path.getsize(MODEL_PATH) / 1024
    print(f"Saved LightGBM model to {MODEL_PATH} ({file_size_kb:.1f} KB)")

    # Feature importances
    importances = dict(zip(feature_cols, booster.feature_importance(importance_type="gain").tolist()))
    sorted_importances = sorted(importances.items(), key=lambda x: x[1], reverse=True)
    print("\nFeature Gain Importances:")
    for feat, gain in sorted_importances:
        print(f"  {feat:28s}: {gain:.1f}")

    # Compute baseline medians and descriptive metadata for fast client/server explainability
    medians = X_train.median().to_dict()
    metadata = {
        "model_version": "1.0.0",
        "feature_cols": feature_cols,
        "auc": round(auc, 4),
        "accuracy": round(acc, 4),
        "medians": medians,
        "importances": dict(sorted_importances),
    }

    with open(META_PATH, "w", encoding="utf-8") as f:
        json.dump(metadata, f, indent=2)
    print(f"Saved forecast metadata and feature baselines to {META_PATH}")


if __name__ == "__main__":
    train_distress_forecast()
