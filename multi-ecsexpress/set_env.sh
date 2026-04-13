#!/bin/bash

# Configuration script for AI Course Creator

if [ -f "$HOME/gemini.key" ]; then
    GOOGLE_API_KEY=$(cat "$HOME/gemini.key")
else
    read -p "Enter Gemini API KEY (from Google AI Studio): " GOOGLE_API_KEY
    echo "$GOOGLE_API_KEY" > "$HOME/gemini.key"
fi

cat <<EOF > .env
# Project Configuration
GENAI_MODEL="gemini-2.5-flash"
LOG_LEVEL=DEBUG

# Authentication
GOOGLE_API_KEY=$GOOGLE_API_KEY
GEMINI_API_KEY=$GOOGLE_API_KEY

# Deployment Context
DEPLOYMENT_ENV="local"
EOF

source .env

echo "Current Environment (.env)"
cat .env

echo "ADK Version"
adk --version 2>/dev/null || echo "ADK not found in PATH"
