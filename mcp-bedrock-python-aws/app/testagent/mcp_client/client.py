import os
import logging
from mcp.client.streamable_http import streamablehttp_client
from strands.tools.mcp.mcp_client import MCPClient

logger = logging.getLogger(__name__)


def get_hello_world_gateway_mcp_client() -> MCPClient | None:
    """Returns an MCP Client connected to the hello-world-gateway gateway."""
    url = os.environ.get("AGENTCORE_GATEWAY_HELLO_WORLD_GATEWAY_URL")
    if not url:
        logger.warning(
            "AGENTCORE_GATEWAY_HELLO_WORLD_GATEWAY_URL not set — "
            "hello-world-gateway gateway tools unavailable"
        )
        return None
    return MCPClient(lambda: streamablehttp_client(url))


def get_all_gateway_mcp_clients() -> list[MCPClient]:
    """Returns MCP clients for all configured gateways."""
    clients = []
    client = get_hello_world_gateway_mcp_client()
    if client:
        clients.append(client)
    return clients
