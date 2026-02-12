import datetime
import json
from typing import Any, Dict, Optional
import logging

from firebase_functions import https_fn
from firebase_admin import firestore, initialize_app

initialize_app()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@https_fn.on_call()
def generate_diet_by_ai(req: https_fn.CallableRequest) -> Any:
    user_id = req.auth.uid if req.auth else None
    payload = req.data if isinstance(req.data, dict) else {}

    if not user_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="userId is required.",
        )
    logger.info(f"Received diet generation request for user ID: {user_id} with payload: {payload}")
    db = firestore.client()

    user_ref = db.collection("users").document(user_id)
    user_snapshot = user_ref.get()
    if not user_snapshot.exists:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.NOT_FOUND,
            message=f"User document not found for {user_id}.",
        )
    prompt = db.collection("prompt").document("prompt_generate_dietplan").get()

    request_payload = {
        "profile": payload.get("profile", {}),
    }
    logger.info(f"Received diet generation payload: {request_payload}")
    request_ref = db.collection("aiDietPlans").document()
    request_ref.set(request_payload)

    return {
        "requestId": request_ref.id,
        "userId": user_id,
        "userExists": True,
    }