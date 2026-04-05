#!/bin/bash
# runadk.sh: Launches the FastAPI backend.

# Get the script's directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Ensure environment is set up
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Go to backend app directory
cd backend/app

# Run the app directly with python to use our SSL logic in main.py
echo "Starting Mission Alpha Biometric Scout Backend..."
python main.py
