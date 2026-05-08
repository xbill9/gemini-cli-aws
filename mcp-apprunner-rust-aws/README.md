# mcp-https-rust

A Rust-based Model Context Protocol (MCP) server designed for deployment on Google Cloud Run, utilizing streaming HTTP.

## Overview

This project implements an MCP server using the [`rmcp`](https://github.com/modelcontextprotocol/rust-sdk) library and the [`axum`](https://docs.rs/axum/latest/axum/) web framework. It provides a `greeting` tool and is optimized for high-performance, streaming communication over HTTP.

## Features

- **MCP Tooling**: Implements a `greeting` tool.
- **Streaming HTTP**: Uses `rmcp`'s `StreamableHttpService` for efficient JSON-RPC over HTTP.
- **Cloud Native**: Pre-configured for Google Cloud Run with a `/health` check endpoint and Docker support.
- **Graceful Shutdown**: Handles SIGINT and SIGTERM for clean exits.

## Getting Started

### Prerequisites

- [Rust Toolchain](https://www.rust-lang.org/tools/install) (2024 edition)
- [Docker](https://docs.docker.com/get-docker/) (for containerization)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (for deployment)

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

### Development Targets

The `Makefile` provides several useful targets:

- `make test`: Run unit tests.
- `make clippy`: Run linting checks.
- `make fmt`: Check code formatting.
- `make start`: Start the server in the background (logs to `server.log`).
- `make stop`: Stop the background server.
- `make status`: Check the status of the background server.

## Deployment

To deploy the application to Google Cloud Run using Google Cloud Build:

```bash
make deploy
```

This will build the Docker image and deploy it to the configured service.

## Protocol Details

This implementation follows the Model Context Protocol (MCP) using the streaming HTTP transport. Sessions are managed locally via `LocalSessionManager`.

## License

MIT
