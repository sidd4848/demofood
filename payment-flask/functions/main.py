import datetime
import logging
from typing import Any, Dict

# [START v2imports]
# Dependencies for callable functions.
from firebase_functions import https_fn

# Dependencies for writing to Realtime Database.
from firebase_admin import db, firestore, initialize_app

DATABASE_URL = "https://foodadvisor-e2cd0-default-rtdb.firebaseio.com"
initialize_app(options={"databaseURL": DATABASE_URL})

def _write_rtdb(path: str, value: Dict[str, Any], child_key: str | None = None) -> None:
    if not DATABASE_URL:
        logging.warning("Skipping RTDB write to %s because the hardcoded DATABASE_URL is empty or invalid.", path)
        return

    ref = db.reference(path)
    if child_key:
        ref = ref.child(child_key)
    if child_key:
        ref.update(value)
    else:
        ref.push(value)



def _extract_uid(req: https_fn.CallableRequest) -> str | None:
    auth_data = req.auth
    if not auth_data:
        return None

    # Callable auth context in Python functions SDK exposes `uid` as an
    # attribute (AuthData), but support dictionary payloads as a defensive
    # fallback for local tests/tooling.
    uid = getattr(auth_data, "uid", None)
    if uid:
        return str(uid)

    if isinstance(auth_data, dict):
        value = auth_data.get("uid")
        return str(value) if value else None

    return None


def _resolve_payload(req: https_fn.CallableRequest) -> Dict[str, Any]:
    payload = req.data if isinstance(req.data, dict) else {}
    nested = payload.get("data")
    if isinstance(nested, dict):
        return nested
    return payload

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
    user_id = _extract_uid(req)
    if not user_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="Unauthorized",
        )

    payload = _resolve_payload(req)

    plan_id = str(payload.get("planId", "")).lower()
    duration_id = str(payload.get("duration", ""))
    duration_months = int(payload.get("durationMonths", 1))
    if plan_id not in {"pro", "elite"}:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Unsupported plan",
        )

    request_data = {
        "basePrice": payload.get("basePrice"),
        "createdAt": payload.get("createdAt"),
        "discountPct": payload.get("discountPct"),
        "duration": duration_id,
        "durationMonths": duration_months,
        "finalPrice": payload.get("finalPrice"),
        "planId": plan_id,
        "region": payload.get("region"),
        "reqId": payload.get("reqId"),
        "status": "payment_done",
        "userId": user_id,
    }

    _write_rtdb("subscriptionUpgradeRequests", request_data)
    firestore.client().collection("subscriptionUpgradeRequests").add(request_data)

    _write_rtdb(
        "users",
        {
            "plan": plan_id,
            "subcriptionId": payload.get("reqId"),
            "subscriptionStatus": "active",
            "subscriptionStart": payload.get("createdAt"),
            "updatedAt": datetime.datetime.utcnow().isoformat(),
        },
        child_key=user_id,
    )

    response = {
        "plan": plan_id,
        "subcriptionId": payload.get("reqId"),
        "subscriptionStatus": "active",
        "subscriptionStart": payload.get("createdAt"),
        "updatedAt": datetime.datetime.utcnow().isoformat(),
    }

    return response
