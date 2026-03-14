# MCP HTTP Python Server for AWS Lightsail

A Model Context Protocol (MCP) server implemented in Python using `FastMCP`, configured for deployment on **Amazon Lightsail Container Services**. This server communicates over `HTTP`.

## Overview

This project provides an MCP server named `hello-world-server` that exposes a `greet` tool. It uses `python-json-logger` for structured logging to stderr, ensuring that stdout remains reserved for JSON-RPC messages. It is specifically pre-configured with a `Makefile` and Docker setup for rapid deployment to AWS Lightsail.

## Prerequisites

- **Python 3.10+**
- **AWS CLI** configured with appropriate permissions.
- **lightsailctl** plugin for AWS CLI.
- **Docker** installed and running.

## Installation

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd mcp-lightsail-python-aws
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

### Deployment to AWS Lightsail
The `Makefile` handles the full deployment lifecycle:
```bash
make deploy
```
This will:
1. Build the Docker image.
2. Push the image to your Lightsail container service.
3. Create a new deployment with the latest image.

## Monitoring Status
You can check both your local git status and the remote Lightsail service status:
```bash
make status
```
Or specifically for Lightsail:
```bash
make lightsail-status
```

## Tools

### `greet`
- **Description:** Get a greeting from the local server.
- **Parameters:**
    - `param` (string): The text or name to echo back.
- **Returns:** The string passed in `param`.

## Development Tasks

- **`make status`**: Show git and Lightsail service status.
- **`make test`**: Run unit tests.
- **`make lint`**: Check code style (flake8).
- **`make format`**: Auto-format code (black).
- **`make type-check`**: Run static type analysis (mypy).
- **`make clean`**: Remove build artifacts and virtual environments.

## Project Structure

- `main.py`: FastMCP server definition and tool implementation.
- `Makefile`: Centralized automation for dev, test, and AWS deployment.
- `Dockerfile`: Container definition for Lightsail.
- `save-aws-creds.sh`: Helper for managing AWS session credentials.
