import os
import logging
from fastapi import FastAPI
from google.adk.cli.fast_api import get_fast_api_app

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Get port from environment
port = int(os.environ.get("PORT", 8000))

# The agents are located in the same directory as this file.
# Since codeLocation is set to "app/", this file and Agent subdirs are in the root of the runtime.
AGENT_DIR = os.path.dirname(os.path.abspath(__file__))

# Initialize ADK FastAPI app
# This serves the ADK Web UI and API for all agents found in AGENT_DIR
app: FastAPI = get_fast_api_app(
    agents_dir=AGENT_DIR,
    web=True,
    host="0.0.0.0",
    port=port,
)

app.title = "ADK Studio"
app.description = "Direct ADK Web Interface for Agent Studio"

if __name__ == "__main__":
    import uvicorn
    logger.info(f"🚀 Starting ADK Studio on port {port}")
    uvicorn.run(app, host="0.0.0.0", port=port)
