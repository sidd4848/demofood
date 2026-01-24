import datetime
import json
from typing import Any, Dict, Optional

import functions_framework
from firebase_admin import auth, credentials, firestore, initialize_app

_APP = initialize_app(credentials.ApplicationDefault())
_DB = firestore.client(_APP)


def _parse_bearer_token(header_value: Optional[str]) -> Optional[str]:
    if not header_value:
        return None
    if not header_value.startswith("Bearer "):
        return None
    return header_value.split(" ", 1)[1].strip()


def _resolve_user_id(request_json: Dict[str, Any], auth_header: Optional[str]) -> Optional[str]:
    token = _parse_bearer_token(auth_header)
    if token:
        try:
            decoded = auth.verify_id_token(token)
            return decoded.get("uid")
        except Exception:
            return None
    user_id = request_json.get("userId")
    if isinstance(user_id, str) and user_id:
        return user_id
    return None


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


@functions_framework.http
def process_subscription_payment(request):
    if request.method != "POST":
        return ("Method not allowed", 405)

    payload = request.get_json(silent=True) or {}
    if not isinstance(payload, dict):
        return ("Invalid request", 400)

    user_id = _resolve_user_id(payload, request.headers.get("Authorization"))
    if not user_id:
        return ("Unauthorized", 401)

    plan_id = str(payload.get("planId", "")).lower()
    duration_id = str(payload.get("duration", ""))
    duration_months = int(payload.get("durationMonths", 1))

    if plan_id not in {"pro", "elite"}:
        return ("Unsupported plan", 400)

    request_ref = _DB.collection("subscriptionUpgradeRequests").document()
    now = datetime.datetime.utcnow()
    txn_id = f"dummy-{request_ref.id[:8]}-{int(now.timestamp())}"

    request_payload = {
        "userId": user_id,
        "planId": plan_id,
        "duration": duration_id,
        "durationMonths": duration_months,
        "currency": payload.get("currency"),
        "region": payload.get("region"),
        "basePrice": payload.get("basePrice"),
        "discountPct": payload.get("discountPct"),
        "finalPrice": payload.get("finalPrice"),
        "status": "payment_started",
        "createdAt": firestore.SERVER_TIMESTAMP,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }

    payment_payload = {
        "status": "paid",
        "txnId": txn_id,
        "creditsApplied": payload.get("credits", 0),
        "paymentProvider": "dummy",
        "paidAt": firestore.SERVER_TIMESTAMP,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }

    batch = _DB.batch()
    batch.set(request_ref, request_payload)
    batch.update(request_ref, payment_payload)

    current_period_end = _add_months(now, duration_months)
    user_update = {
        "plan": plan_id,
        "subscriptionStatus": "active",
        "subscriptionId": txn_id,
        "currentPeriodEnd": current_period_end,
        "quota": _plan_quota(plan_id),
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }
    user_ref = _DB.collection("users").document(user_id)
    batch.set(user_ref, user_update, merge=True)

    batch.commit()

    response = {
        "requestId": request_ref.id,
        "status": "paid",
        "txnId": txn_id,
    }
    return (json.dumps(response), 200, {"Content-Type": "application/json"})
