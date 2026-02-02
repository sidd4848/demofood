# Payment Cloud Function (Firebase)

This folder contains the dummy subscription payment handler (`process_subscription_payment`).

## Prerequisites

* Firebase project on the Blaze (pay-as-you-go) plan (required for 2nd gen functions).
* The following APIs enabled in Google Cloud:
  * Cloud Functions
  * Cloud Build
  * Artifact Registry

If the Firebase CLI reports missing APIs during deploy, allow it to enable them or
enable them in the Google Cloud Console before retrying.

## Deploy to Firebase

1. Install the Firebase CLI and authenticate:
   ```bash
   npm install -g firebase-tools
   firebase login
   ```
2. From the repo root, bind a Firebase project (pick the correct project ID):
   ```bash
   firebase use --add
   ```
3. Deploy the function (uses `firebase.json` to point at this folder):
   ```bash
   firebase deploy --only functions:process_subscription_payment
   ```

The function will be available at:
`https://us-central1-<project-id>.cloudfunctions.net/process_subscription_payment`.

## What the function expects

* HTTP `POST` requests with a Firebase ID token in the `Authorization: Bearer <token>` header.
* JSON body with fields like `planId`, `duration`, `durationMonths`, and pricing metadata.

The function writes:
* `subscriptionUpgradeRequests` documents for the payment request.
* `users/<uid>` updates to activate the subscription and quota.
