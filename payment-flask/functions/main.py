import datetime
import json
from typing import Any, Dict, Optional
import logging

# [START v2imports]
# Dependencies for callable functions.
from firebase_functions import https_fn, options

# Dependencies for writing to Realtime Database.
from firebase_admin import auth, credentials, firestore, initialize_app

initialize_app()

def _plan_quota(plan_id: str) -> Dict[str, Dict[str, int]]:
    if plan_id == "elite":
        return {
            "pro_quota": {"recipe": 999, "diet_regeneration": 999},
            "trial_quota": {"recipe": 0, "diet_regeneration": 0},
        }
    if plan_id == "pro":
        return {
            "pro_quota": {"recipe": 7, "diet_regeneration": 4},
            "trial_quota": {"recipe": 0, "diet_regeneration": 0},
        }
    return {
        "pro_quota": {"recipe": 0, "diet_regeneration": 0},
        "trial_quota": {"recipe": 3, "diet_regeneration": 3},
    }


def _add_months(start: datetime.datetime, months: int) -> datetime.datetime:
    return start + datetime.timedelta(days=30 * max(months, 1))


@https_fn.on_call()
def process_subscription_payment(req: https_fn.CallableRequest) -> Any:

    # user_id = _resolve_user_id(
    #     payload,
    #     request.headers.get("Authorization"),
    # )
    user_id = req.auth.uid  if req.auth else None
    if not user_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="Unauthorized: User ID not found."
        )
    else:
        logging.info(f"Processing subscription payment for user ID: {user_id}")

    plan_id = str(req.data.get("planId", "")).lower()
    duration_id = str(req.data.get("duration", ""))
    duration_months = int(req.data.get("durationMonths", 1))
    if plan_id not in {"pro", "elite"}:
        return ("Unsupported plan", 400)
    
    # Reference to a collection
    # Get a Firestore client instance
    db = firestore.client()
    collection_ref = db.collection("subscriptionUpgradeRequests")
    add_result = collection_ref.add({
        "baseprice": req.data.get("basePrice"),
        "createdAt": req.data.get("createdAt"),
        "discountPct": req.data.get("discountPct"),
        "duration": duration_id,
        "finalPrice": req.data.get("finalPrice"),
        "planId": plan_id,
        "region": req.data.get("region"),
        "reqId": req.data.get("reqId"),
        "status": "payment_done",
        "userId": user_id,
    })
    new_doc_id = add_result[1].id
    logging.info(f"New subscription upgrade request added with ID: {new_doc_id}")


    doc_to_update = user_id
    doc_ref = db.collection("users").document(doc_to_update)
    doc_ref.set({
        "plan": plan_id,
        "subcriptionId": req.data.get("reqId"),
        "subscriptionStatus": "active",
        "subscriptionStart": req.data.get("createdAt"),
        "updatedAt": datetime.datetime.utcnow().isoformat(),
        "currentPeriodEnd": _add_months(datetime.datetime.fromisoformat(req.data.get("createdAt")), duration_months).isoformat()
    }, merge=True)

    return https_fn.Response(
            f"Successfully added document with ID: {new_doc_id} "
            f"and updated it. Check your 'users' collection in Firestore.",
            status=200
        )