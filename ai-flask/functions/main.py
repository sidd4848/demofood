import datetime
from typing import Any

from firebase_functions import https_fn
from firebase_admin import firestore, initialize_app

initialize_app()


@https_fn.on_call()
def generate_diet_by_ai(req: https_fn.CallableRequest) -> Any:
    auth_uid = req.auth.uid if req.auth else None
    payload = req.data if isinstance(req.data, dict) else {}
    user_id = str(payload.get("userId") or "").strip()

    if not auth_uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="Authentication is required.",
        )

    if not user_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="userId is required.",
        )

    if user_id != auth_uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
            message="userId must match the authenticated user.",
        )

    db = firestore.client()

    user_ref = db.collection("users").document(user_id)
    user_snapshot = user_ref.get()
    if not user_snapshot.exists:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.NOT_FOUND,
            message=f"User document not found for {user_id}.",
        )

    request_payload = {
        "userId": user_id,
        "jobId": payload.get("jobId"),
        "model": payload.get("model") or "gemini-1.5-pro",
        "status": "pending",
        "prompt": payload.get("prompt"),
        "responseSchema": payload.get("responseSchema") or {},
        "responseFormat": payload.get("responseFormat") or "json",
        "generatedBy": payload.get("generatedBy") or "ai",
        "createdAt": firestore.SERVER_TIMESTAMP,
        "requestedAt": datetime.datetime.utcnow().isoformat(),
        "user": user_snapshot.to_dict(),
    }

    request_ref = db.collection("aiDietPlans").document()
    request_ref.set(request_payload)

    return {
        "requestId": request_ref.id,
        "userId": user_id,
        "userExists": True,
    }
