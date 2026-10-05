import os
import json
import logging
from typing import Optional, Dict, Any
from fastapi import Header, HTTPException, Depends
import firebase_admin
from firebase_admin import auth, credentials
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("mool-api.deps")

# Initialize Firebase Admin SDK
_firebase_initialized = False

def init_firebase():
    global _firebase_initialized
    if _firebase_initialized or firebase_admin._apps:
        _firebase_initialized = True
        return

    project_id = os.getenv("FIREBASE_PROJECT_ID", "moolorg")
    sa_json = os.getenv("FIREBASE_SA_JSON")

    try:
        if sa_json:
            if sa_json.strip().startswith("{"):
                cred_dict = json.loads(sa_json)
                cred = credentials.Certificate(cred_dict)
                firebase_admin.initialize_app(cred, {"projectId": project_id})
                logger.info("Firebase Admin initialized with inline service account JSON.")
            elif os.path.exists(sa_json.strip()):
                cred = credentials.Certificate(sa_json.strip())
                firebase_admin.initialize_app(cred, {"projectId": project_id})
                logger.info(f"Firebase Admin initialized with service account file: {sa_json}")
        else:
            firebase_admin.initialize_app(options={"projectId": project_id})
            logger.info(f"Firebase Admin initialized with project options: {project_id}")
        _firebase_initialized = True
    except Exception as e:
        logger.warning(f"Firebase Admin initialization warning: {e}. Token verification will run in fallback-aware mode.")

init_firebase()


async def get_current_user(authorization: Optional[str] = Header(None)) -> Dict[str, Any]:
    """
    Verifies Firebase ID token passed via 'Authorization: Bearer <token>'.
    Returns the decoded token dictionary (uid, email, roles, etc.).
    """
    if not authorization:
        # Check if local bypass is allowed
        allow_dev = os.getenv("ALLOW_DEV_ANON_AUTH", "true").lower() == "true"
        if allow_dev:
            return {
                "uid": "dev_anonymous_user",
                "role": "survivor",
                "email": "anonymous@mool.local",
                "is_dev": True
            }
        raise HTTPException(status_code=401, detail="Authorization header missing")

    token = authorization.strip()
    if token.lower().startswith("bearer "):
        token = token[7:].strip()

    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        logger.error(f"Token verification failed: {e}")
        allow_dev = os.getenv("ALLOW_DEV_ANON_AUTH", "true").lower() == "true"
        if allow_dev:
            logger.warning("Falling back to dev anonymous context because ALLOW_DEV_ANON_AUTH is enabled.")
            return {
                "uid": "dev_verified_fallback",
                "role": "survivor",
                "email": "dev@mool.local",
                "is_dev": True
            }
        raise HTTPException(status_code=401, detail="Invalid or expired authentication token")


# Export alias
current_user = get_current_user


_firestore_client = None
_firestore_checked = False

def get_firestore_client():
    """
    Returns an initialized Firestore client, or None if credentials are missing.
    Caches availability to avoid repeated 10s Google ADC lookup timeouts.
    """
    global _firestore_client, _firestore_checked
    if _firestore_checked:
        return _firestore_client

    sa_json = os.getenv("FIREBASE_SA_JSON")
    gac = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    emulator = os.getenv("FIRESTORE_EMULATOR_HOST")

    if not (sa_json or gac or emulator):
        logger.info("No Firebase Service Account or ADC configured; using fast in-memory / local seed store.")
        _firestore_checked = True
        _firestore_client = None
        return None

    try:
        if not firebase_admin._apps:
            init_firebase()
        from firebase_admin import firestore
        _firestore_client = firestore.client()
        _firestore_checked = True
        return _firestore_client
    except Exception as e:
        logger.warning("Could not initialize Firestore client: %s", e)
        _firestore_checked = True
        _firestore_client = None
        return None
