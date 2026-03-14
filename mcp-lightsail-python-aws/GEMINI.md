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
*   `Makefile`: Development and deployment automation.
*   `save-aws-creds.sh`: Script for updating `.aws_creds` file used by the Makefile.

## Development Setup

1.  **Create and activate a virtual environment (optional but recommended):**
    ```bash
    python3 -m venv .venv
    source .venv/bin/activate
    ```

2.  **Update Credentials (if needed):**
    ```bash
    ./save-aws-creds.sh
    ```

3.  **Install Dependencies:**
    ```bash
    make install
    ```

## Running the Server

The server is configured to run using the `HTTP` transport on `http://localhost:8080`.

```bash
make run
```

## Makefile Commands

The `Makefile` is the primary interface for development and deployment tasks:

- **Monitoring:**
    - `make status`: Shows both git status and AWS Lightsail service status.
    - `make git-status`: Shows only git status.
    - `make lightsail-status`: Queries AWS for the current Lightsail container service state.
- **Deployment:**
    - `make deploy`: Full cycle: build, push-lightsail, and create-deployment.
    - `make docker-build`: Build the container image.
    - `make push-lightsail`: Push the container image to Lightsail.
    - `make create-deployment`: Create a new deployment using the latest pushed image.
- **Code Quality:**
    - `make test`: Run pytest suite.
    - `make lint`: Run flake8.
    - `make format`: Run black.
    - `make type-check`: Run mypy.

## Deployment Environment

The project is configured for deployment to **Amazon Lightsail Container Services**.

### Prerequisites
- AWS CLI installed and configured.
- `lightsailctl` plugin installed.
- Docker installed and running.

### Lightsail Plugin (lightsailctl) Installation

The `lightsailctl` plugin is required for the AWS CLI to push container images to Lightsail.

1.  **Download the plugin binary:**
    ```bash
    # For Linux x86_64
    sudo curl "https://s3.us-west-2.amazonaws.com/lightsailctl/latest/linux-amd64/lightsailctl" -o "/usr/local/bin/lightsailctl"

    # For Linux ARM64
    # sudo curl "https://s3.us-west-2.amazonaws.com/lightsailctl/latest/linux-arm64/lightsailctl" -o "/usr/local/bin/lightsailctl"
    ```

2.  **Make it executable:**
    ```bash
    sudo chmod +x /usr/local/bin/lightsailctl
    ```

3.  **Verify installation:**
    ```bash
    lightsailctl --version
    ```

## Python MCP Developer Resources
