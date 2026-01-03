# DemoFood Backend API

A lightweight FastAPI service that currently exposes endpoints to capture user details, generate diet plans with a
transformers-based model, and return a stubbed recipe payload.

Both routes are implemented with `async` handlers so the service can process multiple requests in parallel when run with an ASGI server like Uvicorn.

## Setup

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r backend_foodapi/requirements.txt
```

You can control where user detail payloads are persisted and which model is loaded via `backend_foodapi/storage.yaml`.
The default configuration uses local storage and writes JSON payloads to `backend_foodapi/data/`.

```yaml
storage:
  backend: local
  local_path: data
model:
  model_name: Qwen/Qwen2.5-7B-Instruct
  local_files_only: false
```

**Reducing model download latency**

- Swap in a lighter model (for example `Qwen/Qwen1.5-0.5B-Chat` or `Qwen/Qwen1.5-1.8B-Chat`) by editing `model.model_name`.
- If you have already cached the model locally, set `model.local_files_only: true` to force a cache-only load and avoid
  remote downloads.

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

The payload is also written to `backend_foodapi/data/<jobId>.json` according to the storage settings.

### GET /dietplan/{jobId}

Loads the previously submitted user detail payload by `jobId` and generates a structured weekly diet plan using the
`Qwen/Qwen2.5-7B-Instruct` model from the `transformers` library.

```bash
curl http://127.0.0.1:8000/dietplan/job_1710000000000_ab12cd
```

**Response**
```json
{
  "jobId": "job_1710000000000_ab12cd",
  "plan": {
    "Mon_breakfast": "...",
    "Mon_lunch": "...",
    "Mon_dinner": "...",
    "Tue_breakfast": "...",
    "Tue_lunch": "...",
    "Tue_dinner": "...",
    "Wed_breakfast": "...",
    "Wed_lunch": "...",
    "Wed_dinner": "...",
    "Thu_breakfast": "...",
    "Thu_lunch": "...",
    "Thu_dinner": "...",
    "Fri_breakfast": "...",
    "Fri_lunch": "...",
    "Fri_dinner": "...",
    "Sat_breakfast": "...",
    "Sat_lunch": "...",
    "Sat_dinner": "...",
    "Sun_breakfast": "...",
    "Sun_lunch": "...",
    "Sun_dinner": "..."
  }
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
