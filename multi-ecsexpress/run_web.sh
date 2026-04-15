#!/bin/bash
# run_web.sh - Start only the main app backend

# Set PYTHONPATH to include the root for shared modules
export PYTHONPATH=$PYTHONPATH:/app

echo "Starting Web App in Distributed Mode..."
export PORT=${PORT:-8080}

# Run the main app in foreground
cd app && python3 main.py
