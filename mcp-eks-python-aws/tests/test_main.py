from starlette.testclient import TestClient
from main import mcp, greet

client = TestClient(mcp.http_app())


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy", "service": "mcp-server"}


def test_greet_tool():
    # greet is a FunctionTool in this version of fastmcp
    result = greet.fn("Hello EKS")
    assert result == "Hello EKS"


def test_mcp_metadata():
    assert mcp.name == "hello-world-server"
