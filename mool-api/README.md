---
title: Mool
emoji: 🌿
colorFrom: green
colorTo: green
sdk: gradio
app_file: app.py
pinned: false
---

# Mool (मूल) API — Dynamic Mental Health & Distress Monitoring Microservice

Backend microservice for the Mool platform:
- **AI Proxy**: Secure trauma-informed Groq proxy (`POST /ai/chat`).
- **Scoring Engine**: 4-modality dynamic re-weighting with 5-point hysteresis and silence detection (`POST /ingest`).
- **SLA Escalations & Interventions**: Automated alerts with acknowledgment tracking and explainable recommendations (`GET /alerts`, `GET /recommendations`).
- **Voice & Acoustic Prosody**: Jitter, shimmer, and speech rate stress estimation.
- **Crisis NLP & BNS Privacy**: Deterministic crisis lexicon and BNS Section 72 privacy pseudonymization.
- **LightGBM Forecasting**: 14-day distress risk prediction with TreeSHAP explainability (`POST /forecast/predict`).
- **Multi-Tier Aggregates**: National, state, and district rollups with k-anonymity privacy protection (`GET /aggregates/summary`).
