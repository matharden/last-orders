#!/bin/bash
# Exit on error
set -e

# Load environment variables from .env file
if [ -f .env ]; then
  echo "Loading environment variables from .env..."
  # Use allexport to export all variables declared in .env
  set -a
  source .env
  set +a
else
  echo "Error: .env file not found in the current directory."
  exit 1
fi

# Configuration defaults
SERVICE_NAME="boozer"
REGION="us-central1"

# Automatically extract service account email and project ID from GOOGLE_APPLICATION_CREDENTIALS if it exists
SERVICE_ACCOUNT=""
PROJECT_ID=""
if [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
  echo "Extracting configuration from $GOOGLE_APPLICATION_CREDENTIALS..."
  SERVICE_ACCOUNT=$(node -e "console.log(require('$GOOGLE_APPLICATION_CREDENTIALS').client_email)" 2>/dev/null || \
                   python3 -c "import json; print(json.load(open('$GOOGLE_APPLICATION_CREDENTIALS'))['client_email'])" 2>/dev/null || \
                   grep -o '"client_email": *"[^"]*"' "$GOOGLE_APPLICATION_CREDENTIALS" | head -n 1 | sed 's/"client_email": *"\([^"]*\)"/\1/')

  PROJECT_ID=$(node -e "console.log(require('$GOOGLE_APPLICATION_CREDENTIALS').project_id)" 2>/dev/null || \
               python3 -c "import json; print(json.load(open('$GOOGLE_APPLICATION_CREDENTIALS'))['project_id'])" 2>/dev/null || \
               grep -o '"project_id": *"[^"]*"' "$GOOGLE_APPLICATION_CREDENTIALS" | head -n 1 | sed 's/"project_id": *"\([^"]*\)"/\1/')
fi

if [ -z "$PROJECT_ID" ]; then
  # Fallback to standard environment variables
  PROJECT_ID="${GCP_PROJECT:-$GOOGLE_CLOUD_PROJECT}"
fi

if [ -z "$PROJECT_ID" ]; then
  read -p "Enter Google Cloud Project ID: " PROJECT_ID
  if [ -z "$PROJECT_ID" ]; then
    echo "Error: Project ID is required."
    exit 1
  fi
fi

if [ -z "$SERVICE_ACCOUNT" ]; then
  echo "Warning: Could not extract Service Account email from GOOGLE_APPLICATION_CREDENTIALS."
  echo "Please make sure to set up the Service Account for Cloud Run."
  read -p "Enter Service Account email (or press Enter to let Cloud Run use the default Compute Engine service account): " SERVICE_ACCOUNT_INPUT
  SERVICE_ACCOUNT=$SERVICE_ACCOUNT_INPUT
fi

# Check if the Cloud Run service already exists to get its URL
echo "Checking if Cloud Run service '$SERVICE_NAME' exists in region '$REGION' for project '$PROJECT_ID'..."
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region "$REGION" --project "$PROJECT_ID" --format 'value(status.url)' 2>/dev/null || true)

# If it exists, update redirect and frontend URLs to point to production
if [ -n "$SERVICE_URL" ]; then
  echo "Service exists! URL is: $SERVICE_URL"
  if [[ "$OAUTH_REDIRECT_URL" == *"localhost"* ]] || [ -z "$OAUTH_REDIRECT_URL" ]; then
    OAUTH_REDIRECT_URL="${SERVICE_URL}/callback"
    echo "-> Auto-updating OAUTH_REDIRECT_URL to production: $OAUTH_REDIRECT_URL"
  fi
  if [[ "$FRONTEND_URL" == *"localhost"* ]] || [ -z "$FRONTEND_URL" ]; then
    FRONTEND_URL="${SERVICE_URL}"
    echo "-> Auto-updating FRONTEND_URL to production: $FRONTEND_URL"
  fi
else
  echo "Service does not exist yet. This will be the first deployment."
  echo "We will perform a preliminary deployment to generate the URL."
  # Set temporary redirect URLs since we don't have the final URL yet
  OAUTH_REDIRECT_URL="https://placeholder-url-please-update-after-deploy/callback"
  FRONTEND_URL="https://placeholder-url-please-update-after-deploy"
fi

# Build env vars string for Cloud Run (excluding local file path configs)
ENV_VARS_LIST=(
  "SPREADSHEET_ID=$SPREADSHEET_ID"
  "SHEET_READ_RANGE=$SHEET_READ_RANGE"
  "SHEET_WRITE_RANGE=$SHEET_WRITE_RANGE"
  "OAUTH_REDIRECT_URL=$OAUTH_REDIRECT_URL"
  "GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID"
  "GOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET"
  "AUTHORIZED_EMAIL=$AUTHORIZED_EMAIL"
  "FRONTEND_URL=$FRONTEND_URL"
  "GCS_BUCKET_NAME=$GCS_BUCKET_NAME"
  "ENV=production"
)
# Optional: key for signing session tokens. If unset, the server derives one from
# GOOGLE_CLIENT_SECRET. Use a value without commas (e.g. `openssl rand -hex 32`).
if [ -n "$SESSION_SECRET" ]; then
  ENV_VARS_LIST+=("SESSION_SECRET=$SESSION_SECRET")
fi

# Join the array elements with commas
ENV_VARS=$(IFS=,; echo "${ENV_VARS_LIST[*]}")

# Prepare the deployment command
DEPLOY_CMD="gcloud run deploy $SERVICE_NAME \
  --source . \
  --region $REGION \
  --project $PROJECT_ID \
  --allow-unauthenticated \
  --set-env-vars=\"$ENV_VARS\""

if [ -n "$SERVICE_ACCOUNT" ]; then
  DEPLOY_CMD="$DEPLOY_CMD --service-account=\"$SERVICE_ACCOUNT\""
fi

echo "Executing deployment command:"
echo "$DEPLOY_CMD"
echo ""

eval "$DEPLOY_CMD"

# If it was the first deploy, we need to instruct the user to configure OAuth and redeploy
if [ -z "$SERVICE_URL" ]; then
  # Fetch newly created URL
  NEW_SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region "$REGION" --project "$PROJECT_ID" --format 'value(status.url)' 2>/dev/null || true)
  if [ -n "$NEW_SERVICE_URL" ]; then
    echo "========================================================================="
    echo "🎉 First deployment successful! Service URL: $NEW_SERVICE_URL"
    echo "========================================================================="
    echo "Action Required to complete OAuth 2.0 setup:"
    echo "1. Go to your Google Cloud Console -> APIs & Services -> Credentials."
    echo "2. Edit your OAuth 2.0 Client ID."
    echo "3. Add '${NEW_SERVICE_URL}/callback' to 'Authorized redirect URIs'."
    echo "4. Save the changes."
    echo "5. Run this deploy script again to update the redirect URLs inside Cloud Run."
    echo "========================================================================="
  fi
else
  echo "🎉 Deployment updated successfully!"
fi
