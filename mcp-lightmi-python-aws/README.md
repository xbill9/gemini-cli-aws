# MCP HTTP Python Server for AWS Lightsail

A Model Context Protocol (MCP) server implemented in Python using `FastMCP`, configured for deployment on **Amazon Lightsail Managed Instances (VPS)**. This server communicates over `HTTP`.

## Overview

This project provides an MCP server named `hello-world-server` that exposes a `greet` tool. It uses `python-json-logger` for structured logging to stderr, ensuring that stdout remains reserved for JSON-RPC messages. It is specifically pre-configured with a `Makefile` for rapid deployment to AWS Lightsail VPS, with an alternative path for Container Services.

## Prerequisites

- **Python 3.10+**
- **AWS CLI** configured with appropriate permissions.
- **SSH Client** (for VPS deployment).
- **lightsailctl** plugin (only required for Container Service deployment).
- **Docker** (only required for Container Service deployment).

## Installation

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd mcp-lightmi-python-aws
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

### Deployment to AWS Lightsail (VPS)
The `Makefile` defaults to a Managed Instance deployment:
```bash
make deploy
```
This will:
1. Create a Lightsail instance (default: Debian 13).
2. Open port 8080 in the firewall.
3. Sync the code and install dependencies on the instance.
4. Set up and start a `systemd` service named `mcp-server`.

### Alternative: Deployment to Lightsail Container Services
If you prefer a containerized deployment:
```bash
make lightsail
```
This will:
1. Build the Docker image.
2. Push the image to your Lightsail container service.
3. Create a new deployment with the latest image.

## Monitoring Status
You can check both your local git status and the remote AWS resource status:
```bash
make status
```
Or individually:
- `make instance-status`: Check the VPS status.
- `make lightsail-status`: Check the Container Service status.

## Tools

### `greet`
- **Description:** Get a greeting from the local server.
- **Parameters:**
    - `param` (string): The text or name to echo back.
- **Returns:** The string passed in `param`.

## Development Tasks

- **`make test`**: Run unit tests.
- **`make lint`**: Check code style (flake8).
- **`make format`**: Auto-format code (black).
- **`make type-check`**: Run static type analysis (mypy).
- **`make destroy`**: Destroy ALL AWS resources (both VPS and Container Service).
- **`make instance-destroy`**: Destroy only the VPS.

## Project Structure

- `main.py`: FastMCP server definition and tool implementation.
- `Makefile`: Centralized automation for dev, test, and AWS deployment.
- `scripts/setup-instance.sh`: Instance initialization script for VPS.
- `Dockerfile`: Container definition for Lightsail.
- `save-aws-creds.sh`: Helper for managing AWS session credentials.
