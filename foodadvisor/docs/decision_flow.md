# Decision Flow Documentation

This document describes the key user flows and the decision tree logic that governs subscription upgrades and AI diet generation.

## 1) Upgrade plan flow

**High-level flow**
1. **Upgrade Plan screen loads** and retrieves:
   - `SubscriptionConfig` (pricing, regions, durations)
   - Current user subscription summary
2. **Region pricing is resolved** from the config using:
   - `data.regionCode` → `locale.countryCode` → fallback `'IN'`
3. **Plan card selection** determines upgrade behavior:
   - If the active plan matches the card, the action is disabled.
   - Otherwise, the user is prompted to select a subscription duration.
4. **Duration picker** computes final pricing and returns selection.
5. **Upgrade request is written** to `subscriptionUpgradeRequests`.

**Decision tree**
```
Upgrade Plan Screen
├─ Fetch pricing config + subscription summary
├─ Resolve region pricing
│  ├─ If regionCode exists in config → use it
│  └─ Else → use default / first region entry
├─ For each plan card
│  ├─ If active plan == card plan → disable upgrade action
│  └─ Else → open duration picker
│     ├─ For each duration
│     │  ├─ total = basePrice * months
│     │  ├─ discount = total * discountPct / 100
│     │  └─ finalPrice = total - discount
│     └─ On pick → submit upgrade request
└─ Submit request (subscriptionUpgradeRequests)
```

## 2) AI diet generation flow

**High-level flow**
1. **User taps “Generate by AI.”**
2. The system checks **recent AI requests**:
   - Looks up the latest request for the user, ordered by `createdAt`.
   - If there is a request within the last 7 days, the user is asked for tweaks.
3. A **prompt template** is loaded from Firestore (`prompt/prompt_generate_dietplan`).
4. The template is filled with user profile data and optional tweaks.
5. The **AI request payload is stored** in `aiDietPlans`.

**Decision tree**
```
Generate by AI
├─ Check for recent request (last 7 days)
│  ├─ If recent request exists → ask for tweaks
│  │  ├─ If user cancels tweaks → stop
│  │  └─ Else → include tweaks in prompt
│  └─ If no recent request → continue without tweaks
├─ Fetch prompt template
│  ├─ If missing → error
│  └─ Else → apply template with user data
└─ Store AI request (aiDietPlans)
```

## 3) Firestore collections involved

- `subscriptionConfig` (pricing/regions/durations)
- `subscriptionUpgradeRequests` (upgrade submissions)
- `aiDietPlans` (AI diet generation requests)
- `prompt/prompt_generate_dietplan` (prompt template for AI)
