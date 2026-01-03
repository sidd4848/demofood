# DemoFood Backend API

A lightweight FastAPI service that currently exposes two endpoints:

- `POST /userdetail`: accepts a structured JSON body describing a user's profile, preferences, frequency, `jobId`, and
  `submittedAt`, and echoes the same data back.
- `GET /recipe`: returns a stubbed recipe payload.

Both routes are implemented with `async` handlers so the service can process multiple requests in parallel when run with an ASGI server like Uvicorn.

## Setup

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r backend_foodapi/requirements.txt
```

## Running the server

```bash
uvicorn backend_foodapi.main:app --reload
```

## Usage

### POST /userdetail

Required fields:

- `profile.name`, `profile.gender`, `profile.age`, `profile.heightCm`, `profile.weightKg`
- `preferences.dietType`
- `jobId`
- `submittedAt`

Other fields are optional.

```bash
curl -X POST \
  http://127.0.0.1:8000/userdetail \
  -H "Content-Type: application/json" \
  -d @- <<'JSON'
{
  "profile": {
    "name": "Alex",
    "gender": "Male",
    "age": 30,
    "heightCm": 175.0,
    "weightKg": 72.5,
    "bodyFatPct": null,
    "visceralFatPct": null
  },
  "preferences": {
    "dietType": "veg",
    "nonVegItems": [],
    "cuisines": ["Italian", "Indian"],
    "allergies": ["peanuts"],
    "healthSymptoms": ["blood pressure", "diabetes"]
  },
  "frequency": {
    "Breakfast": { "mode": "everyday" },
    "Dinner": { "mode": "weekdays", "weekdays": [1, 3, 5] }
  },
  "jobId": "job_1710000000000_ab12cd",
  "submittedAt": "2024-03-09T12:34:56.789Z"
}
JSON
```

**Response**
```json
{
  "profile": {
    "name": "Alex",
    "gender": "Male",
    "age": 30,
    "heightCm": 175.0,
    "weightKg": 72.5,
    "bodyFatPct": null,
    "visceralFatPct": null
  },
  "preferences": {
    "dietType": "veg",
    "nonVegItems": [],
    "cuisines": ["Italian", "Indian"],
    "allergies": ["peanuts"],
    "healthSymptoms": ["blood pressure", "diabetes"]
  },
  "frequency": {
    "Breakfast": { "mode": "everyday" },
    "Dinner": { "mode": "weekdays", "weekdays": [1, 3, 5] }
  },
  "jobId": "job_1710000000000_ab12cd",
  "submittedAt": "2024-03-09T12:34:56.789Z"
}
```

### GET /recipe

```bash
curl http://127.0.0.1:8000/recipe
```

**Response**
```json
{
  "name": "Avocado Toast",
  "ingredients": {
    "bread": "2 slices",
    "avocado": "1 ripe",
    "lemon": "1 tsp",
    "salt": "pinch",
    "pepper": "pinch"
  },
  "instructions": "Toast the bread, mash the avocado with lemon, salt, and pepper, then spread over the toast."
}
```

## Health check

```bash
curl http://127.0.0.1:8000/
```

**Response**
```json
{"status":"DemoFood API is running"}
```
