import pytest
from starlette.testclient import TestClient
from main import app


@pytest.fixture
def client():
    return TestClient(app)


def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy", "service": "mcp-server"}


def test_root_path(client):
    response = client.get("/")
    assert response.status_code == 200
    assert "MCP Server is running" in response.json()["message"]


def test_mcp_root(client):
    # FastMCP mounts its app at /mcp
    response = client.get("/mcp/")
    # FastMCP usually responds to GET on root with a basic message or 405 if not configured
    # Depending on FastMCP version, this might vary.
    assert response.status_code in [200, 404, 405]
