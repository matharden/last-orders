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

### Step 1: Assign Roles to your Service Account
Ensure the Service Account you created earlier has permissions to access the Google Sheet and GCS bucket.

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
