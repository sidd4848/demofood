# foodadvisor

A new Flutter project.

## Submission payload example

Profile submissions (used for both local saves and API posts) are built from the form
data plus submission metadata. The payload structure is:

- `profile`: Basic details such as `name`, `gender`, `age`, `heightCm`, `weightKg`,
  `bodyFatPct`, and `visceralFatPct`.
- `preferences`: Diet selections and health concerns including `dietType`,
  `nonVegItems`, `cuisines`, `allergies`, and `healthSymptoms`.
- `frequency`: Meal frequency selections keyed by meal name.
- `jobId`: A unique identifier generated per submission.
- `submittedAt`: UTC timestamp (ISO 8601) for when the payload was built.

Example JSON produced by the app:

```
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

The `jobId` is generated from the timestamp and a short random hex suffix, and the
`submittedAt` field is always in UTC.
