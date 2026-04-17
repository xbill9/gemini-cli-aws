#!/bin/bash
# Local development startup script
echo "Starting Biometric Security System (Local)..."
echo "Local URL: http://127.0.0.1:8080/"

# Ensure we are in the project root
cd "$(dirname "$0")"

# Run the backend
python backend/app/main.py
