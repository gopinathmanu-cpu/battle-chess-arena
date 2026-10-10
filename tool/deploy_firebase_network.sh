#!/usr/bin/env bash
set -euo pipefail

firebase_project_id="${1:-}"
cloud_region="${FIREBASE_CLOUD_REGION:-asia-south1}"
service_name="battle-chess-arena-firebase"
expected_protocol="4"

if [[ -z "$firebase_project_id" ]]; then
  echo "Usage: ./tool/deploy_firebase_network.sh YOUR_FIREBASE_PROJECT_ID"
  exit 2
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "Google Cloud CLI is required: https://cloud.google.com/sdk/docs/install"
  exit 1
fi

echo "Using Firebase/Google Cloud project: $firebase_project_id"
gcloud config set project "$firebase_project_id"

echo "Enabling the required Cloud Run build services..."
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  firestore.googleapis.com

if ! gcloud firestore databases describe --database='(default)' >/dev/null 2>&1; then
  echo "Creating the durable Firestore database for profiles and rankings..."
  gcloud firestore databases create \
    --database='(default)' \
    --location="$cloud_region" \
    --type=firestore-native \
    --quiet
fi

project_number="$(gcloud projects describe "$firebase_project_id" --format='value(projectNumber)')"
runtime_service_account="${project_number}-compute@developer.gserviceaccount.com"
echo "Granting durable leaderboard storage access to the Cloud Run service..."
gcloud projects add-iam-policy-binding "$firebase_project_id" \
  --member="serviceAccount:$runtime_service_account" \
  --role='roles/datastore.user' \
  --condition=None \
  --quiet >/dev/null

build_service_account="$(gcloud builds get-default-service-account)"
if ! gcloud projects get-iam-policy "$firebase_project_id" \
  --flatten='bindings[].members' \
  --filter="bindings.role:roles/run.builder AND bindings.members:$build_service_account" \
  --format='value(bindings.role)' | grep -q '^roles/run.builder$'; then
  echo "Granting the required Cloud Run Builder permission..."
  gcloud projects add-iam-policy-binding "$firebase_project_id" \
    --member="serviceAccount:$build_service_account" \
    --role='roles/run.builder' \
    --condition=None \
    --quiet >/dev/null
  echo "Waiting briefly for the new permission to become active..."
  for _ in 1 2 3 4 5 6; do sleep 15; done
fi

echo "Deploying the Battle Chess Arena network server..."
gcloud run deploy "$service_name" \
  --source server \
  --region "$cloud_region" \
  --allow-unauthenticated \
  --timeout 3600 \
  --concurrency 80 \
  --cpu 1 \
  --memory 512Mi \
  --cpu-throttling \
  --min-instances 0 \
  --max-instances 1 \
  --session-affinity \
  --service-account "$runtime_service_account" \
  --update-env-vars "FIRESTORE_PROJECT_ID=$firebase_project_id,FIRESTORE_DATABASE=(default)"

service_url="$(
  gcloud run services describe "$service_name" \
    --region "$cloud_region" \
    --format='value(status.url)'
)"
socket_url="wss://${service_url#https://}"

echo "Verifying the deployed Firebase match protocol..."
health_json="$(curl --fail --silent --show-error --retry 8 --retry-all-errors \
  --retry-delay 3 "$service_url/health")"
actual_protocol="$(
  HEALTH_JSON="$health_json" node -e \
    'const health = JSON.parse(process.env.HEALTH_JSON); process.stdout.write(String(health.protocolVersion ?? ""));'
)"
if [[ "$actual_protocol" != "$expected_protocol" ]]; then
  echo "Deployment health check returned protocol ${actual_protocol:-unknown}; expected $expected_protocol" >&2
  exit 1
fi
durable_storage="$(
  HEALTH_JSON="$health_json" node -e \
    'const health = JSON.parse(process.env.HEALTH_JSON); process.stdout.write(String(health.durableStorage === true));'
)"
if [[ "$durable_storage" != "true" ]]; then
  echo "Deployment health check did not confirm durable leaderboard storage" >&2
  exit 1
fi

echo
echo "Deployment complete."
echo "Health check: $service_url/health"
echo "Verified protocol: $actual_protocol"
echo "Durable profiles and leaderboard: enabled"
echo
echo "Build the app with:"
echo "flutter build apk --release --dart-define=ONLINE_SERVER_URL=$socket_url"
