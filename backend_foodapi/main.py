from typing import Dict

from fastapi import FastAPI
from pydantic import BaseModel, Field


class UserDetailRequest(BaseModel):
    date: str = Field(description="ISO-8601 date representing when the job runs")
    job_id: str = Field(description="Identifier for the job associated with the user detail")


class UserDetailResponse(UserDetailRequest):
    """Echo the submitted user detail payload."""


class RecipeResponse(BaseModel):
    name: str
    ingredients: Dict[str, str]
    instructions: str


app = FastAPI(title="DemoFood API")


@app.post("/userdetail", response_model=UserDetailResponse)
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
