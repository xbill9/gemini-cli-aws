# Tool Provider: hello_world_server

This is the core MCP server for the AgentCore system. It is implemented using `FastMCP` and provides managed tools to the AgentCore Gateway.

## Implementation Details

- **Framework:** `mcp` (FastMCP)
- **Transport:** Streamable HTTP (`stateless_http=True`)
- **Port:** Defaults to `8000` (configurable via `PORT` environment variable)
- **Logging:** JSON formatted logs via `python-json-logger` sent to `stderr`.

## Endpoints

### MCP Tools
- **`greet`**: A simple tool that echoes the input parameter.
    - **Input:** `param` (string)
    - **Output:** Greeting string

### Custom Routes
- **`/health`**: Standard GET endpoint for status checks.
    - **Response:** `{"status": "healthy", "service": "mcp-server"}`

## Local Development

To run the server locally:
```bash
make run
```
Or directly:
```bash
python server.py
```

**Note:** In production (AgentCore Runtime), the server is started via the `server:mcp` handler as configured in `agentcore.json`.
