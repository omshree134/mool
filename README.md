# Mool (मूल) — AI-Powered Grounded Mental Health Platform

[![Release](https://img.shields.io/github/v/release/omshree134/mool?color=green&label=APK%20Release)](https://github.com/omshree134/mool/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-v3.8+-02569B?logo=flutter)](https://flutter.dev)
[![React](https://img.shields.io/badge/React-18-61DAFB?logo=react)](https://reactjs.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Cloudflare Workers](https://img.shields.io/badge/Cloudflare_Workers-Edge-F38020?logo=cloudflare)](https://workers.cloudflare.com)

**Mool** (*"root"* in Hindi/Sanskrit) is an AI-powered dynamic mental health monitoring, crisis intervention, and distress prediction platform designed with trauma-informed principles. Mool provides quiet, private monitoring that connects individuals with human responders before crises escalate — without feeling surveillant, clinical, or cold.

---

## 📱 Download Mobile App (Android APK)

The compiled, production-ready release APK is available directly in [**GitHub Releases**](https://github.com/omshree134/mool/releases/latest).

- **Latest Release**: [Download `app-release.apk`](https://github.com/omshree134/mool/releases/latest)
- **Supported Android OS**: Android 8.0+ (API level 26+)

---

## 🏛️ Monorepo Architecture

The platform consists of four unified modules:

```
Mool/
├── mool/            # 📱 Flutter Mobile App (Survivor / Beneficiary Client)
├── mool-web/        # 💻 Web Portal (Caseworker & Administrator Dashboards)
├── mool-worker/     # ⚡ Cloudflare Edge Worker (Always-on API Gateway & Router)
├── mool-api/        # 🧠 ML & Analytics Microservice (FastAPI + LightGBM + NLP)
└── app-update.md    # 📐 Architecture Specifications & Roadmap
```

### 1. `mool/` — Flutter Mobile Application
A trauma-informed mobile client offering:
- **Zero-Friction Onboarding**: Anonymous local-first setup with QR pairing.
- **Gentle Check-ins**: Multilingual sentiment, voice notes, and emotional logs.
- **Talk to Mool**: Privacy-focused AI companion grounded in trauma-informed guidance.
- **Crisis SOS**: Instant 1-tap emergency dispatch and Tele-MANAS hotline integration.
- **On-Device Sensing**: Ambient accelerometer and pedometer activity tracking.

### 2. `mool-web/` — Web Portal & Command Center
A React 18 + Vite responsive portal for healthcare workers and administrators:
- **Beneficiary Management**: Pairing code generation and case intake.
- **Distress Alert Queue**: Real-time AI triage (Acknowledge, Escalate, Dispatch, Close).
- **Population Wellbeing**: Aggregated sentiment metrics and SLA monitoring.
- **IVRS Simulator**: Interactive dialer and phone simulation tool.

### 3. `mool-worker/` — Cloudflare Edge Gateway
Edge-deployed proxy ensuring uninterrupted availability:
- **CORS Management & Edge Routing**: Low-latency request dispatch.
- **LLM Proxy & Lexicon Guardrails**: Deterministic crisis checks with immediate fallback.
- **Automated Cron Jobs**: Scheduled ticks every 10 minutes for SLA escalation.

### 4. `mool-api/` — Backend AI & Scoring Microservice
FastAPI service handling computation-heavy machine learning:
- **Distress Forecasting**: LightGBM model trained on behavioral longitudinal indicators.
- **Trauma-Informed NLP**: Structured emotion extraction and crisis detection.
- **ASR & Voice Stress Prosody**: Speech-to-text and acoustic feature analysis.

---

## 🔐 Security & Secrets Management

This repository does **not** contain production credentials, service account tokens, or API keys:
- Copy any `.env.example` file to `.env` in the respective directory and provide your keys.
- Copy `mool/android/app/google-services.json.example` to `google-services.json` for Firebase mobile setup.
- Worker secrets should be set using `wrangler secret put <KEY_NAME>`.

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK** (v3.24+)
- **Node.js** (v18+) & `npm`
- **Python** (3.10+)
- **Android Studio** / Android SDK (for mobile compilation)

### Running the Flutter Mobile App
```bash
cd mool
flutter pub get
flutter run
```

### Running the Web Dashboard
```bash
cd mool-web
npm install
npm run dev
```

### Running the API Microservice
```bash
cd mool-api
pip install -r requirements.txt
uvicorn app.main:app --reload --port 7860
```

### Running the Edge Worker
```bash
cd mool-worker
npm install
npm run dev
```

---

## 📄 License
This project is open-source under the MIT License.
