#!/bin/bash
# Configuration
# The deployment is now managed by the Makefile for consistency.
# This script is kept for compatibility and as a shortcut.

echo "Initiating Lambda deployment via Makefile..."

# Export GOOGLE_API_KEY if it exists in the home directory
if [ -f "${HOME}/gemini.key" ]; then
    export GOOGLE_API_KEY=$(cat "${HOME}/gemini.key")
fi

make deploy
