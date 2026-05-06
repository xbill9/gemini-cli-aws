from starlette.testclient import TestClient
from main import mcp, greet

# FastMCP in the mcp SDK exposes the Starlette app via streamable_http_app()
client = TestClient(mcp.streamable_http_app())


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy", "service": "mcp-server"}


def test_greet_tool():
    result = greet("Hello Fargate")
    assert result == "Hello Fargate"


def test_mcp_metadata():
    assert mcp.name == "hello_world_server"
