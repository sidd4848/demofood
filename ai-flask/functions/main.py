import datetime
import json
from pydantic import BaseModel
from typing import Any, Dict, Optional
import logging

import re

from firebase_functions import https_fn
from firebase_admin import firestore, initialize_app

initialize_app()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

from pydantic import BaseModel

class Meal(BaseModel):
    breakfast: str
    lunch: str
    dinner: str

class WeeklyDietPlan(BaseModel):
    Mon: Meal
    Tue: Meal
    Wed: Meal
    Thu: Meal
    Fri: Meal
    Sat: Meal
    Sun: Meal


def check_quota(quota: int, user_id: str) -> dict:
    if quota == 0:
        return {
                "userId": user_id,
                "quotaExceeded": True
            }
    return {
        "userId": user_id,
        "quotaExceeded": False
    }

def generate_diet_plan(prompt, user_data, user_ref):
    # replace $dietType, $weight, $height, $body_fat_pct and $visceral_fat_pct, $symptoms, in prompt
    prompt_text = prompt.to_dict().get("prompt", "")
    diet_type = user_data.get("profile").get("preferences").get("dietType")
    weight = user_data.get("profile").get("profile").get("weightKg")
    height = user_data.get("profile").get("profile").get("height")
    body_fat_pct = user_data.get("profile").get("profile").get("body_fat_pct", None)
    visceral_fat_pct = user_data.get("profile").get("profile").get("visceral_fat_pct", None)
    symptoms = user_data.get("profile").get("preferences").get("healthSymptoms", [])
    prompt_text = re.sub(r"\$dietType", diet_type, prompt_text)
    prompt_text = re.sub(r"\$weight", str(weight), prompt_text)
    if height is not None:
        height = f"{height} cm"
    prompt_text = re.sub(r"\$height", str(height), prompt_text)
    if body_fat_pct is not None:
        body_fat_pct = f"{body_fat_pct}% body fat"
    prompt_text = re.sub(r"\$body_fat_pct", str(body_fat_pct), prompt_text)
    visceral_fat_pct = user_data.get("visceral_fat_pct", None)
    if visceral_fat_pct is not None:
        visceral_fat_pct = f"{visceral_fat_pct}% visceral fat"
    prompt_text = re.sub(r"\$visceral_fat_pct", str(visceral_fat_pct), prompt_text)
    if symptoms:
        symptoms_str = ", ".join(symptoms)
        prompt_text = re.sub(r"\$symptoms", symptoms_str, prompt_text)

    print(f"Final prompt text: {prompt_text}")

    import vertexai
    from vertexai.generative_models import GenerativeModel, GenerationConfig
    
    vertexai.init(
        project="foodadvisor-e2cd0",
        location="us-central1"
    )

    generation_config = GenerationConfig(
                            temperature=0.4,
                            max_output_tokens=2000,
                            response_mime_type="application/json",
                            response_schema=WeeklyDietPlan.model_json_schema(),
                        )

    # Load the Gemini Pro model
    model = GenerativeModel("gemini-2.0-flash-001")

    # Generate a diet plan based on the prompt
    response = model.generate_content(
                        prompt_text,
                        generation_config=generation_config
                    )

    print(f"Generated diet plan response: {response.text}")
    diet_plan = WeeklyDietPlan.model_validate_json(response.text)
    print(f"Parsed diet plan: {diet_plan}")

    # Store the generated diet plan in Firestore

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
    print(f"Received diet generation request for user ID: {user_id} with payload: {payload}")
    db = firestore.client()

    user_ref = db.collection("users").document(user_id)
    user_snapshot = user_ref.get()
    if not user_snapshot.exists:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.NOT_FOUND,
            message=f"User document not found for {user_id}.",
        )

    user_data = user_snapshot.to_dict()
    print(f"Received diet generation payload: {user_data}, type: {type(user_data)}  ")
    try:
        plan = user_data.get("plan")
        type_req = payload.get("type_request")
        subscriptionStatus = user_data.get("subscriptionStatus")
        if (plan == "elite" or plan == "pro") and subscriptionStatus == "active":
            quota_dic = user_data.get("quota").get("pro_quota")
        else:
            quota_dic = user_data.get("quota").get("trial_quota")
        
        if type_req == "generate_diet":
            quota = quota_dic.get("diet_regeneration")
        else:
            quota = quota_dic.get("recipe")

        quota_check_result = check_quota(quota, user_id)
        if quota_check_result["quotaExceeded"]:
            return quota_check_result
        
        prompt = db.collection("prompt").document(type_req).get()

        generate_diet_plan(prompt, user_data, user_ref)

        
        #update quota
        user_ref.set({
            "quota": {
                "pro_quota": {
                    "recipe": quota_dic.get("recipe"),
                    "diet_regeneration": max(quota_dic.get("diet_regeneration") - 1, 0)
                },
                "trial_quota": {
                    "recipe": quota_dic.get("recipe"),
                    "diet_regeneration": max(quota_dic.get("diet_regeneration") - 1, 0)
                }
            }
        }, merge=True)

    except Exception as e:
        logger.error(f"Error processing diet generation request for user ID: {user_id}: {str(e)}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"An error occurred while processing the request: {str(e)}",
        )

    # print(f"user_snapshot data: {user_data.profile}, type: {type(user_data.profile)}  ")
    request_ref = db.collection("aiDietPlans").document()
    request_ref.set(user_data)

    return {
        "requestId": request_ref.id,
        "userId": user_id,
        "userExists": True,
    }