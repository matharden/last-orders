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

When you are ready to deploy, you can use the Google Cloud CLI (`gcloud`). You don't even need Docker installed locally, as Cloud Build can handle the containerization for you!

```bash
# Submit the build to GCP and deploy to Cloud Run
gcloud run deploy boozer \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars="SPREADSHEET_ID=...,OAUTH_REDIRECT_URL=https://your-cloud-run-url/callback,..."
```

*(Note: In production, remember to update your `OAUTH_REDIRECT_URL` to the public Cloud Run URL, and add that URL to your GCP OAuth Client's authorized redirect URIs!)*
