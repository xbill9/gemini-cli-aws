# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the project and assist in development.

## Project Overview

This is a **Python-based Model Context Protocol (MCP) server** using the `FastMCP` class from the `mcp` SDK. It is designed to expose tools (like `greet`) over HTTP for integration with MCP clients (such as Claude Desktop or Gemini clients).

## Key Technologies

*   **Language:** Python 3
*   **SDK:** `mcp` (Model Context Protocol SDK)
*   **Library:** `FastMCP` (for simplified server creation)
*   **Logging:** `python-json-logger`
*   **Dependency Management:** `pip` / `requirements.txt`

## Project Structure

*   `main.py`: The entry point of the application. Initializes the `FastMCP` server ("hello-world-server") and defines tools.
*   `requirements.txt`: Python dependencies.
*   `Makefile`: Development shortcuts (test, lint, clean). *Note: Some targets in the Makefile may reference legacy paths and might need adjustment.*

## Development Setup

1.  **Create and activate a virtual environment (optional but recommended):**
    ```bash
    python3 -m venv .venv
    source .venv/bin/activate
    ```

2.  **Install Dependencies:**
    ```bash
    pip install -r requirements.txt
    ```

## Running the Server

The server is configured to run using the `HTTP` transport on `http://localhost:8080`.

```bash
python main.py
```

## Deployment

The project is configured for deployment to **Amazon Lightsail Container Services**.

### Prerequisites
- AWS CLI installed and configured.
- `lightsailctl` plugin installed.
- Docker installed and running.

### Deployment Commands
- `make docker-build`: Build the Docker image locally.
- `make deploy`: Build, push the image to Lightsail, and create a new deployment.

## Python MCP Developer Resources
