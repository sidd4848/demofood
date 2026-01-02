# DemoFood Backend API

A lightweight FastAPI service that currently exposes two endpoints:

- `POST /userdetail`: accepts a JSON body containing `date` and `job_id` and echoes the same data back.
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

```bash
curl -X POST \
  http://127.0.0.1:8000/userdetail \
  -H "Content-Type: application/json" \
  -d '{"date": "2024-01-01", "job_id": "job-123"}'
```

**Response**
```json
{
  "date": "2024-01-01",
  "job_id": "job-123"
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
