import gradio as gr
from app.main import app as fastapi_app

# Create a clean documentation dashboard for the Gradio landing view
with gr.Blocks(title="Mool (मूल) API Platform") as demo:
    gr.Markdown("""
    # 🌿 Mool (मूल) Backend Microservice
    
    The Mool dynamic distress monitoring and trauma-informed AI platform is live.
    
    ### API Endpoints
    - **Interactive API Docs (Swagger UI)**: [`/docs`](/docs)
    - **OpenAPI JSON**: [`/openapi.json`](/openapi.json)
    - **AI Companion Proxy**: `POST /ai/chat`
    - **Multi-Channel Ingest**: `POST /ingest`
    - **14-Day Distress Forecasting (LightGBM + TreeSHAP)**: `POST /forecast/predict`
    - **SLA Alerts & Escalations**: `GET /alerts`, `POST /alerts/{id}/ack`
    - **Explainable Interventions**: `GET /recommendations`
    - **Aggregates (k-anonymity masked)**: `GET /aggregates/summary`
    - **Heartbeat & Cron**: `POST /cron/tick`
    """)

# Mount FastAPI app onto Gradio
app = gr.mount_gradio_app(fastapi_app, demo, path="/")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7860)
