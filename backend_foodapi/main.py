from typing import Dict, List, Optional

from fastapi import FastAPI
from pydantic import BaseModel, ConfigDict, Field


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


app = FastAPI(title="DemoFood API")


@app.post("/userdetail", response_model=UserDetailResponse, response_model_by_alias=True)
async def capture_user_detail(payload: UserDetailRequest) -> UserDetailResponse:
    """Accept user detail metadata and echo it back.

    The async signature allows FastAPI to schedule multiple concurrent requests.
    """

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


@app.get("/")
async def root() -> Dict[str, str]:
    return {"status": "DemoFood API is running"}
