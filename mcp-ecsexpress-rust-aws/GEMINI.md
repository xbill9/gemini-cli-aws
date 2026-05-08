# Gemini Workspace for `mcp-ecsexpress-rust-aws`

You are a Rust Developer working with Amazon AWS.
Follow Rust best practices and idiomatic patterns (2024 edition).

## Project Overview

`mcp-ecsexpress-rust-aws` is a streaming HTTP MCP server written in Rust, designed for deployment on Amazon ECS using **Express Mode**. It uses the `rmcp` library to provide tools to LLM agents via the Model Context Protocol.

### Key Technologies

*   **Language:** Rust (2024 Edition)
*   **MCP Framework:** [`rmcp`](https://github.com/modelcontextprotocol/rust-sdk) (v1.6.0)
*   **Web Framework:** [Axum](https://docs.rs/axum/latest/axum/) (v0.8.9)
*   **Containerization:** Docker
*   **Deployment:** Amazon ECS (Express Mode)

## Development Workflow

### Useful Commands

- `make run`: Starts the server locally on port 8080.
- `make build`: Compiles the project for development.
- `make test`: Runs unit tests in `src/main.rs`.
- `make clippy`: Runs linting.
- `make format`: Formats the code.
- `make start`/`stop`/`status`: Manage background server process.
- `make deploy` or `make ecs`: Deploys to Amazon ECS Express Mode.
- `make monitor`: Monitor the ECS deployment progress.
- `make ecs-status`: Check ECS service status.
- `make endpoint`: Get the public URL.

### Implementation Details

- **Entry Point:** `src/main.rs` defines the `HelloWorld` struct which implements `ServerHandler`.
- **Streaming HTTP:** The server uses `StreamableHttpService` from `rmcp` to handle long-lived HTTP connections for MCP sessions.
- **Health Check:** A `/health` endpoint is provided for AWS health probes.
- **Environment Variables:** `PORT` determines the listening port. `ALLOWED_HOSTS` configures DNS rebinding protection.
- **Graceful Shutdown:** Implemented using `tokio::signal`.

## Documentation References

- [rmcp Documentation](https://docs.rs/rmcp/latest/rmcp/)
- [Axum Documentation](https://docs.rs/axum/latest/axum/)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [Amazon ECS Express Mode](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/express-service-create-full.html)

## Tips for Gemini

- **Adding Tools:** Use the `#[tool]` attribute in the `HelloWorld` impl block. Ensure the `tool_router` is correctly initialized in `new()`.
- **Tool Parameters:** Ensure all parameter structs implement `serde::Deserialize` and `schemars::JsonSchema`.
- **Local Sessions:** The `LocalSessionManager` handles MCP session state locally.
- **Tracing:** Use `tracing` for logging. The subscriber is initialized in `main`.
