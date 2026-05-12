# mcp-ebs-rust-aws

A Rust-based Model Context Protocol (MCP) server designed for deployment on Amazon Elastic Beanstalk (EBS), utilizing streaming HTTP.

## Overview

This project implements an MCP server using the [`rmcp`](https://github.com/modelcontextprotocol/rust-sdk) library and the [`axum`](https://docs.rs/axum/latest/axum/) web framework. It provides a `greeting` tool and is optimized for high-performance, streaming communication over HTTP.

## Features

- **MCP Tooling**: Implements a `greeting` tool.
- **Streaming HTTP**: Uses `rmcp`'s `StreamableHttpService` for efficient JSON-RPC over HTTP.
- **AWS Native**: Pre-configured for Amazon Elastic Beanstalk with a `/health` check endpoint and Docker support.
- **Graceful Shutdown**: Handles SIGINT and SIGTERM for clean exits.

## Tools

The following tools are provided by this MCP server:

### `greeting`

Echoes back a message with a friendly greeting.

**Parameters:**
- `message` (string, required): The message to echo back.

**Example Response:**
`"Hello World MCP! <message>"`

## Getting Started

### Prerequisites

- [Rust Toolchain](https://www.rust-lang.org/tools/install) (2024 edition)
- [Docker](https://docs.docker.com/get-docker/) (for containerization)
- [AWS CLI](https://aws.amazon.com/cli/) (for deployment)

### Build

To build the project for release:

```bash
cargo build --release
```

### Run Locally

The server listens on the port specified by the `PORT` environment variable (default: `8080`).

```bash
# Using Makefile
make run

# Or directly
cargo run --release
```

The server will be available at `http://localhost:8080`.
You can check the health at `http://localhost:8080/health`.

### Configuration

The server can be configured using the following environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | The port to listen on. | `8080` |
| `ALLOWED_HOSTS` | Comma-separated list of allowed hostnames (e.g., `localhost,my-app.aws.com`). | `0.0.0.0,localhost,127.0.0.1` |

### Development Targets

The `Makefile` provides several useful targets:

- `make test`: Run unit tests.
- `make clippy`: Run linting checks.
- `make fmt`: Check code formatting.
- `make start`: Start the server in the background (logs to `server.log`).
- `make stop`: Stop the background server.
- `make status`: Check the deployment status (alias for `eb-status`).

## Deployment

To deploy the application to Amazon Elastic Beanstalk:

```bash
# Initialize EB application and S3 bucket (if not already done)
make eb-init

# Package and deploy
make deploy

# Check status
make eb-status

# Get public endpoint
make eb-endpoint
```

This will package the source code into a `source.zip` and deploy it to the configured Elastic Beanstalk environment.

## Protocol Details

This implementation follows the Model Context Protocol (MCP) using the streaming HTTP transport. Sessions are managed locally via `LocalSessionManager`.

## License

MIT
