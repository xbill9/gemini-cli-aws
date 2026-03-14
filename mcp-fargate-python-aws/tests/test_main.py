from starlette.testclient import TestClient
from main import mcp, greet

client = TestClient(mcp._app)


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy", "service": "mcp-server"}


def test_greet_tool():
    result = greet("Hello Fargate")
    assert result == "Hello Fargate"


def test_mcp_metadata():
    assert mcp.name == "hello-world-server"
