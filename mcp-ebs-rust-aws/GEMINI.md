# Gemini Workspace for `mcp-ebs-rust-aws`

You are a Rust Developer working with Amazon AWS.
Follow Rust best practices and idiomatic patterns (2024 edition).

## Project Overview

`mcp-ebs-rust-aws` is a streaming HTTP MCP server written in Rust, designed for deployment on Amazon Elastic Beanstalk. It uses the `rmcp` library to provide tools to LLM agents via the Model Context Protocol.

### Key Technologies

*   **Language:** Rust (2024 Edition)
*   **MCP Framework:** [`rmcp`](https://github.com/modelcontextprotocol/rust-sdk) (v1.6.0)
*   **Web Framework:** [Axum](https://docs.rs/axum/latest/axum/) (v0.8.9)
*   **Containerization:** Docker
*   **Deployment:** Amazon Elastic Beanstalk (EBS)

## Development Workflow

### Useful Commands

- `make run`: Starts the server locally on port 8080.
- `make build`: Compiles the project for development.
- `make test`: Runs unit tests in `src/main.rs`.
- `make clippy`: Runs linting.
- `make format`: Formats the code.
- `make start`/`stop`/`status`: Manage background server process.
- `make eb-init`: Initialize AWS Elastic Beanstalk application and environment.
- `make deploy`: (Recommended) Packages the pre-built binary and deploys to EBS (faster, avoids timeouts).
- `make eb-deploy`: Deploys source code to EBS (builds on instance, might timeout on small instances).
- `make eb-status`: Check deployment status.
- `make eb-endpoint`: Get the public URL.

### Implementation Details

- **Entry Point:** `src/main.rs` defines the `HelloWorld` struct which implements `ServerHandler`.
- **Streaming HTTP:** The server uses `StreamableHttpService` from `rmcp` to handle long-lived HTTP connections for MCP sessions.
- **Health Check:** A `/health` endpoint is provided for EB health probes.
- **Environment Variables:**
    - `PORT`: Determines the listening port (default: 8080).
    - `ALLOWED_HOSTS`: Comma-separated list of allowed hostnames for DNS rebinding protection (e.g., `localhost,*.elasticbeanstalk.com`). Use `*` to allow all (not recommended for production).
- **Graceful Shutdown:** Implemented using `tokio::signal`.
- **Status Aliases:** `make status` is an alias for `make eb-status`. Use `make local-status` (if added) or check `server.pid` for local process status.

## Documentation References

- [rmcp Documentation](https://docs.rs/rmcp/latest/rmcp/)
- [Axum Documentation](https://docs.rs/axum/latest/axum/)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)

## Tips for Gemini

- **Adding Tools:** Use the `#[tool]` attribute in the `HelloWorld` impl block. Ensure the `tool_router` is correctly initialized in `new()`.
- **Tool Parameters:** Ensure all parameter structs implement `serde::Deserialize` and `schemars::JsonSchema`.
- **Local Sessions:** The `LocalSessionManager` handles MCP session state locally.
- **Tracing:** Use `tracing` for logging. The subscriber is initialized in `main`.
