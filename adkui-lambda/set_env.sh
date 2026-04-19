#!/bin/bash

# Setup Gemini API Key
if [ -f "$HOME/gemini.key" ]; then
    GOOGLE_API_KEY=$(cat "$HOME/gemini.key")
elif [ -n "$GOOGLE_API_KEY" ]; then
    echo "$GOOGLE_API_KEY" > "$HOME/gemini.key"
else
    read -p "Enter Gemini API KEY: " GOOGLE_API_KEY
    echo "$GOOGLE_API_KEY" > "$HOME/gemini.key"
fi

# Set a dummy project ID if not found for ADK compatibility
if [ -f "$HOME/project_id.txt" ]; then
    PROJECT_ID=$(cat "$HOME/project_id.txt")
else
    PROJECT_ID="adkui-lambda"
    echo "$PROJECT_ID" > "$HOME/project_id.txt"
fi

cat <<EOF > .env
GOOGLE_GENAI_USE_VERTEXAI=false
GOOGLE_CLOUD_PROJECT=$PROJECT_ID
GOOGLE_CLOUD_LOCATION=us-central1
GOOGLE_API_KEY=$GOOGLE_API_KEY
GEMINI_API_KEY=$GOOGLE_API_KEY
GEMINI_KEY=$GOOGLE_API_KEY
MODEL_ID="gemini-3.1-flash-live-preview"
PORT=8080
EOF

source .env

echo "Current Environment:"
cat .env

echo "ADK Version:"
adk --version
