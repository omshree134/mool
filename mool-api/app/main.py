import os
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

from .routers import ai, cron, ingest, cases, alerts, nlp, ivrs, whatsapp, forecast, aggregates

load_dotenv()

# Setup structured logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("mool-api")

app = FastAPI(
    title="Mool API — Dynamic Mental Health & Distress Monitoring",
    description="Backend microservice for Mool platform: secure AI companion proxy, multi-channel ingestion, distress scoring, and automated SLA escalations.",
    version="1.0.0",
)

# Configure CORS
raw_origins = os.getenv("CORS_ORIGINS", "*")
if raw_origins.strip() == "*":
    origins = ["*"]
else:
    origins = [o.strip() for o in raw_origins.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register sub-routers
app.include_router(ai.router)
app.include_router(cron.router)
app.include_router(ingest.router)
app.include_router(cases.router)
app.include_router(alerts.router)
app.include_router(nlp.router)
app.include_router(ivrs.router)
app.include_router(whatsapp.router)
app.include_router(forecast.router)
app.include_router(aggregates.router)


@app.get("/", tags=["Health"])
async def root():
    return {
        "platform": "Mool (मूल)",
        "service": "mool-api",
        "status": "online",
        "docs": "/docs",
        "version": "1.0.0"
    }


@app.get("/health", tags=["Health"])
async def health_check():
    has_groq = bool(os.getenv("GROQ_API_KEY"))
    project_id = os.getenv("FIREBASE_PROJECT_ID", "moolorg")
    return {
        "status": "healthy",
        "firebase_project": project_id,
        "groq_configured": has_groq,
    }


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 7860))
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=True)
