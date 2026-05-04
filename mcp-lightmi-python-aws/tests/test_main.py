import pytest


def test_greet():
    # Test the greet tool directly if possible, or via mcp.call_tool
    # For FastMCP, tools are registered and can be found in mcp._tools

    # Simple direct call if it's decorated normally
    from main import greet

    assert greet("hello") == "hello"


@pytest.mark.asyncio
async def test_health_check():
    from main import health_check

    # mock request
    class MockRequest:
        pass

    response = await health_check(MockRequest())
    assert response.status_code == 200
    import json

    data = json.loads(response.body)
    assert data["status"] == "healthy"
