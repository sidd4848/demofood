import json
import logging
import re
from pathlib import Path
from typing import Dict, List, Optional

import torch
import yaml
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, ConfigDict, Field
from transformers import AutoModelForCausalLM, AutoTokenizer


class Profile(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    name: str
    gender: str
    age: int
    height_cm: float = Field(..., alias="heightCm")
    weight_kg: float = Field(..., alias="weightKg")
    body_fat_pct: Optional[float] = Field(None, alias="bodyFatPct")
    visceral_fat_pct: Optional[float] = Field(None, alias="visceralFatPct")


class Preferences(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    diet_type: str = Field(..., alias="dietType")
    non_veg_items: Optional[List[str]] = Field(default_factory=list, alias="nonVegItems")
    cuisines: Optional[List[str]] = None
    allergies: Optional[List[str]] = None
    health_symptoms: Optional[List[str]] = Field(None, alias="healthSymptoms")


class MealFrequency(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    mode: str
    weekdays: Optional[List[int]] = None


class UserDetailRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    profile: Profile
    preferences: Preferences
    frequency: Dict[str, MealFrequency] = Field(default_factory=dict)
    job_id: str = Field(..., alias="jobId")
    submitted_at: str = Field(..., alias="submittedAt", description="ISO-8601 timestamp when details were submitted")


class UserDetailResponse(UserDetailRequest):
    """Echo the submitted user detail payload."""


class RecipeResponse(BaseModel):
    name: str
    ingredients: Dict[str, str]
    instructions: str


class StorageSettings(BaseModel):
    backend: str = "local"
    local_path: Path = Field(default_factory=lambda: Path("data"))


class LocalStorage:
    """Persist user detail payloads to the local filesystem."""

    def __init__(self, base_path: Path) -> None:
        self.base_path = Path(base_path)
        self.base_path.mkdir(parents=True, exist_ok=True)

    def save_user_detail(self, job_id: str, payload: Dict) -> Path:
        target = self.base_path / f"{job_id}.json"
        target.write_text(json.dumps(payload, indent=2))
        return target

    def load_user_detail(self, job_id: str) -> Dict:
        target = self.base_path / f"{job_id}.json"
        if not target.exists():
            raise FileNotFoundError(f"No payload found for jobId {job_id}")
        return json.loads(target.read_text())


def load_storage_settings(config_path: Path) -> StorageSettings:
    if not config_path.exists():
        return StorageSettings()

    with config_path.open("r", encoding="utf-8") as config_file:
        raw_config = yaml.safe_load(config_file) or {}

    return StorageSettings(**raw_config)


class DietPlanResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    job_id: str = Field(..., alias="jobId")
    plan: Dict[str, str]


class DietPlanGenerator:
    """Generate structured diet plans using a causal language model."""

    def __init__(self, model_name: str = "Qwen/Qwen2.5-7B-Instruct") -> None:
        self.model_name = model_name
        self._tokenizer: Optional[AutoTokenizer] = None
        self._model: Optional[AutoModelForCausalLM] = None
        self.device = "cuda" if torch.cuda.is_available() else "cpu"

    @property
    def tokenizer(self) -> AutoTokenizer:
        if self._tokenizer is None:
            self._tokenizer = AutoTokenizer.from_pretrained(self.model_name)
        return self._tokenizer

    @property
    def model(self) -> AutoModelForCausalLM:
        if self._model is None:
            model_kwargs = {"device_map": "auto"} if torch.cuda.is_available() else {}
            self._model = AutoModelForCausalLM.from_pretrained(self.model_name, **model_kwargs)
            if not torch.cuda.is_available():
                self._model = self._model.to(self.device)
        return self._model

    def _extract_json(self, text: str) -> Dict[str, str]:
        match = re.search(r"\{.*\}", text, flags=re.DOTALL)
        if not match:
            raise ValueError("Model response did not contain JSON content")

        parsed = json.loads(match.group(0))
        return {k: str(v) for k, v in parsed.items()}

    def generate_plan(self, user_detail: UserDetailRequest) -> Dict[str, str]:
        prompt = (
            "generate a diet plan with following input:\n"
            f"{json.dumps(user_detail.model_dump(by_alias=True), indent=2)}\n"
            "Respond strictly as JSON with keys Mon_breakfast, Mon_lunch, Mon_dinner, "
            "Tue_breakfast, Tue_lunch, Tue_dinner, Wed_breakfast, Wed_lunch, Wed_dinner, "
            "Thu_breakfast, Thu_lunch, Thu_dinner, Fri_breakfast, Fri_lunch, Fri_dinner, "
            "Sat_breakfast, Sat_lunch, Sat_dinner, Sun_breakfast, Sun_lunch, Sun_dinner. "
            "Each value should be a concise meal description with calorie estimates."
        )

        tokens = self.tokenizer(prompt, return_tensors="pt").to(self.device)
        outputs = self.model.generate(**tokens, max_new_tokens=512)
        response_text = self.tokenizer.decode(outputs[0], skip_special_tokens=True)

        try:
            parsed_plan = self._extract_json(response_text)
        except Exception as error:  # noqa: BLE001
            logging.exception("Failed to parse model output: %s", error)
            raise HTTPException(status_code=500, detail="Unable to parse generated plan")

        expected_keys = [
            f"{day}_{meal}"
            for day in ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            for meal in ["breakfast", "lunch", "dinner"]
        ]

        return {key: parsed_plan.get(key, "Details unavailable") for key in expected_keys}


CONFIG_PATH = Path(__file__).with_name("storage.yaml")
storage_settings = load_storage_settings(CONFIG_PATH)
storage_backend = LocalStorage(storage_settings.local_path)
plan_generator = DietPlanGenerator()


app = FastAPI(title="DemoFood API")


@app.post("/userdetail", response_model=UserDetailResponse, response_model_by_alias=True)
async def capture_user_detail(payload: UserDetailRequest) -> UserDetailResponse:
    """Accept user detail metadata and echo it back.

    The async signature allows FastAPI to schedule multiple concurrent requests.
    """

    storage_backend.save_user_detail(payload.job_id, payload.model_dump(by_alias=True))
    return UserDetailResponse(**payload.model_dump())


@app.get("/recipe", response_model=RecipeResponse)
async def get_recipe() -> RecipeResponse:
    """Return a stubbed recipe payload."""

    return RecipeResponse(
        name="Avocado Toast",
        ingredients={
            "bread": "2 slices",
            "avocado": "1 ripe",
            "lemon": "1 tsp",
            "salt": "pinch",
            "pepper": "pinch",
        },
        instructions=(
            "Toast the bread, mash the avocado with lemon, salt, and pepper, then spread "
            "over the toast."
        ),
    )


@app.get("/dietplan/{job_id}", response_model=DietPlanResponse, response_model_by_alias=True)
async def build_diet_plan(job_id: str) -> DietPlanResponse:
    """Generate a structured diet plan for a previously submitted jobId."""

    try:
        raw_payload = storage_backend.load_user_detail(job_id)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Unknown jobId")

    user_detail = UserDetailRequest.model_validate(raw_payload)
    plan = plan_generator.generate_plan(user_detail)

    return DietPlanResponse(job_id=job_id, plan=plan)


@app.get("/")
async def root() -> Dict[str, str]:
    return {"status": "DemoFood API is running"}
