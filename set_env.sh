cat <<EOF> .env
GOOGLE_GENAI_USE_VERTEXAI=1
GOOGLE_CLOUD_PROJECT=$(gcloud config get-value project)
GOOGLE_CLOUD_LOCATION=us-central1
IMAGEN_MODEL="imagen-3.0-fast-generate-001"
GENAI_MODEL="gemini-2.5-flash"
EOF

source .env
