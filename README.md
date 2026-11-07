# Last Orders Web App

A lightweight Go web application that uses built-in Google OAuth 2.0 authentication to secure the app and integrates with the Google Sheets API v4 to read and write data.

## 🏗️ Architecture Summary

*   **Backend (`main.go`, `sheets/sheets.go`, `gcs/gcs.go`):** Built with Go's `net/http` package. It handles OAuth login, Google Sheets synchronization, image uploading/signing via Google Cloud Storage (GCS), and exposes API endpoints (`/api/*`).
*   **Frontend (`frontend/`):** A modern UI built with Svelte and Vite. In production, this compiles into static assets served by Go from `/app/static` on port `8080`.
*   **Deployment (`Dockerfile`):** A multi-stage Dockerfile that builds the Svelte assets first, then compiles the Go server and embeds the static Svelte distribution into a lean container.

## ⚙️ Configuration & Prerequisites

Before you can run the application, you need to set up your Google Cloud project and gather some credentials. The application relies on a `.env` file to function securely.

> **IMPORTANT:** You must create a **Service Account** to access the Google Sheet and GCS bucket, and an **OAuth 2.0 Client** to handle user login.

### Environment Variables Needed

Create a `.env` file in the root directory (where `main.go` is) with the following variables:

```bash
# 1. Google Sheets Configuration
SPREADSHEET_ID="your-google-sheet-id-here"
SHEET_READ_RANGE="Booze log!A:F"
SHEET_WRITE_RANGE="Booze log!A:F"
GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/service-account-key.json"

# 2. Google Cloud Storage Configuration
GCS_BUCKET_NAME="your-gcs-bucket-name"

# 3. Authentication Configuration (OAuth 2.0)
GOOGLE_CLIENT_ID="your-oauth-client-id.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET="your-oauth-client-secret"
OAUTH_REDIRECT_URL="http://localhost:8080/callback"
AUTHORIZED_EMAIL="your.email@gmail.com" # Only this email can log in
FRONTEND_URL="http://localhost:5173"
# Optional: key for signing sign-in sessions (e.g. `openssl rand -hex 32`).
# If unset it is derived from GOOGLE_CLIENT_SECRET. Changing it signs everyone out.
SESSION_SECRET=""
```

### Setup Steps
1.  **Google Sheet:** Create a Google Sheet. Share it with the email address of your Service Account (giving it Editor access).
2.  **Service Account:** In GCP Console, create a Service Account, generate a JSON key, and save it in your project folder. This path becomes your `GOOGLE_APPLICATION_CREDENTIALS`.
3.  **OAuth Credentials:** In GCP Console (APIs & Services > Credentials), create an OAuth 2.0 Client ID for a Web Application. Add `http://localhost:8080/callback` and `http://localhost:5173/callback` to the Authorized redirect URIs.

## 🚀 Running Locally (Docker Compose)

The application uses Docker Compose to orchestrate both the Go backend and Svelte frontend in development.

1. Ensure your `.env` file is set up correctly in the root.
2. Build and start the containers:
   ```bash
   docker-compose up --build
   ```

### 🔌 Port Guide for Development

When running Docker Compose, the application is accessible on two ports:

*   **Port `5173` (Vite Development Server - USE THIS FOR FRONTEND DEV)**
    *   **Hot Module Replacement (HMR):** Watches frontend files and instantly updates your browser without reloading.
    *   **Proxy Configuration:** Automatically proxies API and OAuth routes (`/api`, `/login`, etc.) to the Go backend.
    *   **URL:** Navigate to `http://localhost:5173` to develop.
*   **Port `8080` (Go Backend)**
    *   Exposes backend JSON API routes and OAuth callbacks.
    *   Serves a **static** build of the frontend, which does *not* auto-update as you edit code during development.
    *   **URL:** `http://localhost:8080` (used by the frontend proxy under the hood).

## ☁️ Deploying to Cloud Run

The easiest way to deploy to Google Cloud Run is by using the provided deployment script, which automates sourcing environment variables from your `.env` file, extracting your service account credentials, and setting up the production URL redirects.

### Step 1: Assign Roles and Permissions to your Service Account
1. **Google Sheets & Cloud Storage Permissions:** Ensure the Service Account you created earlier has permissions to edit the Google Sheet and read/write to the GCS bucket.
2. **IAM URL Signing Permissions (Critical):** Since the backend signs temporary GCS URLs on demand, you must grant the Service Account permission to sign data as itself:
   * **Enable the API:** Go to the [IAM Service Account Credentials API Page](https://console.cloud.google.com/apis/library/iamcredentials.googleapis.com) and click **Enable**.
   * **Assign Role:** Go to the [IAM Page](https://console.cloud.google.com/iam-admin/iam), click **Grant Access**, add your service account email as a principal, and assign the **Service Account Token Creator** (`roles/iam.serviceAccountTokenCreator`) role. This is required for the IAM `signBlob` API to succeed on Cloud Run.

### Step 2: Run the Deployment Script

Simply run the executable script from the root directory:

```bash
./deploy.sh
```

#### First Deployment (OAuth Setup)
Because Google OAuth requires an authorized redirect URI pointing to your live URL (which you only get *after* deployment), the first run of the script will:
1. Perform a preliminary deployment using placeholders.
2. Print your new live Cloud Run service URL.
3. Instruct you to add `<YOUR_SERVICE_URL>/callback` to the **Authorized redirect URIs** in your Google Cloud Console (APIs & Services > Credentials).
4. Prompt you to run `./deploy.sh` one more time to automatically update the environment variables on Cloud Run with the live URL.

#### Subsequent Deployments
For any future changes, just run `./deploy.sh`. The script will automatically detect the existing service, retrieve its URL, adjust the callback redirect URL to production, and redeploy.

## 📱 Native iOS App

A native SwiftUI port of the app lives in `ios/` (`ios/LastOrders.xcodeproj`). It is a full client for the same backend — Home (weekly measure), Journal, Stats, and Cellar screens, plus the log/edit bottom sheets and catalog photo upload — with the same UK-units maths as the web frontend (`ios/LastOrders/Units.swift` mirrors `frontend/src/lib/units.js`; keep them in sync).

*   **Backend:** Talks to the deployed Cloud Run service over the existing `/api/*` endpoints. No backend changes are required.
*   **Auth:** Tap *Sign in with Google* in Settings (shown automatically on first launch). The app opens the server's `/login?app=ios`, and the server's `/callback` hands back a signed session token via `lastorders://auth`. The token is stored in the Keychain, sent as `Authorization: Bearer <token>`, lasts a year and is renewed automatically (`X-Session-Token` response header). The web app gets the same kind of signed token in its `auth_session` cookie, valid for 90 days and renewed while in use.
*   **Requirements:** Xcode 16+, iOS 17+.

### Running on your iPhone
1. Open `ios/LastOrders.xcodeproj` in Xcode.
2. Select the *LastOrders* target → Signing & Capabilities → choose your personal team (a free Apple ID works).
3. Plug in your iPhone (enable Developer Mode under Settings → Privacy & Security if prompted), select it as the run destination, and press Run.
4. In the app's Settings sheet, confirm the server URL and tap *Sign in with Google* using the account your server's `AUTHORIZED_EMAIL` is set to.

> Note: with a free (non-paid) Apple developer account, the app signature expires after 7 days — just press Run again to reinstall.
