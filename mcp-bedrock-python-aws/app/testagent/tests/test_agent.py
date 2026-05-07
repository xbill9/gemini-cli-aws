import pytest
from agent import AgentRequest


def test_agent_request_model():
    # Valid request
    req = AgentRequest(prompt="Hello")
    assert req.prompt == "Hello"

    # Invalid request
    with pytest.raises(Exception):
        AgentRequest(not_a_prompt="Hello")


@pytest.mark.asyncio
async def test_invoke_invalid_payload():
    # Mock payload missing 'prompt'
    payload = {"foo": "bar"}
    context = {}

    # Call the entrypoint directly
    from agent import invoke
    results = []
    async for part in invoke(payload, context):
        results.append(part)

    assert len(results) == 1
    assert "Error: Invalid payload" in results[0]
