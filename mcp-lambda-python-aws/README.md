# MCP HTTP Python Server for AWS App Runner

A Model Context Protocol (MCP) server implemented in Python using `FastMCP`, configured for deployment on **AWS App Runner**. This server communicates over `HTTP`.

## Overview

This project provides an MCP server named `hello-world-server` that exposes a `greet` tool. It uses `python-json-logger` for structured logging to stderr, ensuring that stdout remains reserved for JSON-RPC messages. It is specifically pre-configured with a `Makefile` and Docker setup for rapid deployment to AWS App Runner via Amazon ECR.

## Prerequisites

- **Python 3.10+**
- **AWS CLI** configured with appropriate permissions.
- **Docker** installed and running.

## Installation

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd mcp-apprunner-python-aws
    ```

2.  **Set up credentials:**
    If you use temporary credentials (e.g., from AWS SSO or a lab environment), run the helper script to export them for the Makefile:
    ```bash
    ./save-aws-creds.sh
    ```

3.  **Install dependencies:**
    ```bash
    make install
    ```

## Usage

### Local Running
To run the server manually:
```bash
make run
# or
python main.py
```
The server starts on `http://localhost:8080` by default.

### Deployment to AWS App Runner
The `Makefile` handles the full deployment lifecycle:
```bash
make deploy
```
This will:
1. Ensure the necessary IAM role (`AppRunnerECRAccessRole`) exists.
2. Build the Docker image.
3. Login to Amazon ECR and push the image.
4. Create or update the App Runner service.

## Monitoring Status
You can check both your local git status and the remote App Runner service status:
```bash
make status
```
Or specifically for App Runner:
```bash
make apprunner-status
```

## Tools

### `greet`
- **Description:** Get a greeting from the local server.
- **Parameters:**
    - `param` (string): The text or name to echo back.
- **Returns:** The string passed in `param`.

## Development Tasks

- **`make status`**: Show git and App Runner service status.
- **`make test`**: Run unit tests (if configured).
- **`make lint`**: Check code style (flake8).
- **`make format`**: Auto-format code (black).
- **`make clean`**: Remove build artifacts and virtual environments.

## Project Structure

- `main.py`: FastMCP server definition and tool implementation.
- `Makefile`: Centralized automation for dev, test, and AWS deployment.
- `Dockerfile`: Container definition for App Runner.
- `save-aws-creds.sh`: Helper for managing AWS session credentials.
