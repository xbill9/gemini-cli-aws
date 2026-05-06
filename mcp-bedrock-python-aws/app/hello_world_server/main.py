# main.py

import logging
# main.py

import logging
import sys
import os

from mcp.server.fastmcp import FastMCP

# Set up logging
logging.basicConfig(level=logging.INFO, stream=sys.stderr)
logger = logging.getLogger(__name__)

# Get port from environment
port = int(os.environ.get("PORT", 8000))

# Initialize FastMCP server
mcp = FastMCP(
    "hello_world_server", host="0.0.0.0", port=port, stateless_http=True
)

@mcp.tool()
def greet(param: str) -> str:
    """Echo the input parameter."""
    logger.info(f"Greet tool called with param: {param}")
    return param

if __name__ == "__main__":
    logger.info(f"🚀 MCP server starting on port {port}")
    mcp.run(transport="streamable-http")
