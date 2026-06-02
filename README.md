# Boozer Web App

A lightweight Go web application that uses built-in Google OAuth 2.0 authentication to secure the app and integrates with the Google Sheets API v4 to read and write data.

## 🏗️ Architecture Summary

*   **Backend (`main.go`, `sheets/sheets.go`):** Built with the standard Go `net/http` package. It requires Google Sign-in to access the dashboard, and uses a Service Account to manage data in Google Sheets.
*   **Frontend (`static/`):** A modern, dark-themed UI built with Vanilla HTML, CSS (`style.css`), and JavaScript (`app.js`). It communicates with the Go backend via JSON APIs (`/api/data`).
*   **Deployment (`Dockerfile`):** A multi-stage Dockerfile that compiles the Go app into a lean, secure container ready for Google Cloud Run.

## ⚙️ Configuration & Prerequisites

Before you can run the application, you need to set up your Google Cloud project and gather some credentials. The application relies on a `.env` file to function securely.

> **IMPORTANT:** You must create a **Service Account** to access the Google Sheet, and an **OAuth 2.0 Client** to handle user login.

### Environment Variables Needed

Create a `.env` file in the root directory (where `main.go` is) with the following variables:

```bash
# 1. Google Sheets Configuration
SPREADSHEET_ID="your-google-sheet-id-here"
SHEET_READ_RANGE="Sheet1!A2:B"
SHEET_WRITE_RANGE="Sheet1!A:B"
GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/service-account-key.json"

# 2. Authentication Configuration (OAuth 2.0)
GOOGLE_CLIENT_ID="your-oauth-client-id.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET="your-oauth-client-secret"
OAUTH_REDIRECT_URL="http://localhost:8080/callback"
AUTHORIZED_EMAIL="your.email@gmail.com" # Only this email can log in
```

### Setup Steps
1.  **Google Sheet:** Create a Google Sheet. Share it with the email address of your Service Account (giving it Editor access).
2.  **Service Account:** In GCP Console, create a Service Account, generate a JSON key, and save it in your project folder. This path becomes your `GOOGLE_APPLICATION_CREDENTIALS`.
3.  **OAuth Credentials:** In GCP Console (APIs & Services > Credentials), create an OAuth 2.0 Client ID for a Web Application. Add `http://localhost:8080/callback` to the Authorized redirect URIs.

## 🚀 Running Locally

Running the app locally is incredibly fast! The application uses `godotenv` to automatically load your `.env` file.

1. Open your terminal in the `boozer` directory.
2. Ensure your `.env` file is set up correctly.
3. Run the application:
```bash
go run .
```
4. Open your browser and navigate to `http://localhost:8080`. You will be prompted to log in with your Google account.

## ☁️ Deploying to Cloud Run

When deploying to Google Cloud Run, **you do not need to upload or use the `GOOGLE_APPLICATION_CREDENTIALS` JSON file.** 

Instead, the best practice is to assign your Service Account directly to the Cloud Run service. The Go application will automatically detect that it's running on GCP and use the assigned Service Account's permissions!

### Step 1: Assign Roles to your Service Account
Ensure the Service Account you created earlier has permissions to access the Google Sheet. 

### Step 2: First Deploy (to get your URL)
Because you need the Cloud Run URL to configure Google OAuth, but you need Google OAuth configured to use the app, you have to do a "dummy" deploy first to generate the URL.

```bash
# Deploy with placeholder OAuth URL
gcloud run deploy boozer \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --service-account="<YOUR_SERVICE_ACCOUNT_EMAIL>" \
  --set-env-vars="SPREADSHEET_ID=...,OAUTH_REDIRECT_URL=placeholder,GOOGLE_CLIENT_ID=...,GOOGLE_CLIENT_SECRET=...,AUTHORIZED_EMAIL=..."
```

After this command finishes, it will print your actual Cloud Run URL (e.g., `https://boozer-xyz-uc.a.run.app`).

### Step 3: Update OAuth Credentials & Re-deploy
1. Take your new Cloud Run URL, add `/callback` to the end, and put it in the **Authorized redirect URIs** in your GCP OAuth Console.
2. Re-run the deploy command, but this time use the real URL:

```bash
gcloud run deploy boozer \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --service-account="<YOUR_SERVICE_ACCOUNT_EMAIL>" \
  --set-env-vars="SPREADSHEET_ID=...,OAUTH_REDIRECT_URL=https://<YOUR_ACTUAL_URL>/callback,GOOGLE_CLIENT_ID=...,GOOGLE_CLIENT_SECRET=...,AUTHORIZED_EMAIL=..."
```
