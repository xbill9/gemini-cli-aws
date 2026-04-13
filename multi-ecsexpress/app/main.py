import json
import logging
import os
import re
import traceback
from collections.abc import AsyncGenerator
from typing import Any

import httpx
from a2a_utils import a2a_card_dispatch
from authenticated_httpx import create_authenticated_client
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from fastapi.staticfiles import StaticFiles
from httpx_sse import aconnect_sse
from logging_config import get_uvicorn_log_config, setup_logging
from opentelemetry import trace
from opentelemetry.exporter.cloud_trace import CloudTraceSpanExporter
from opentelemetry.sdk.trace import TracerProvider, export
from pydantic import BaseModel
from starlette.middleware.base import BaseHTTPMiddleware


class Feedback(BaseModel):
    score: float
    text: str | None = None
    run_id: str | None = None
    user_id: str | None = None


# Standardized logging setup
setup_logging("course-creator-web")
logger = logging.getLogger(__name__)

provider = TracerProvider()
processor = export.BatchSpanProcessor(
    CloudTraceSpanExporter(),
)
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(BaseHTTPMiddleware, dispatch=a2a_card_dispatch)

agent_name = os.getenv("AGENT_NAME", None)
agent_server_url = os.getenv("AGENT_SERVER_URL")
if agent_server_url:
    agent_server_url = agent_server_url.rstrip("/")

clients: dict[str, httpx.AsyncClient] = {}


async def get_client(agent_server_origin: str) -> httpx.AsyncClient:
    global clients
    if agent_server_origin not in clients:
        logger.info(f"Creating authenticated client for {agent_server_origin}")
        clients[agent_server_origin] = create_authenticated_client(agent_server_origin)
    return clients[agent_server_origin]


async def create_session(
    agent_server_origin: str, agent_name: str, user_id: str
) -> dict[str, Any]:
    logger.info(f"Creating session for agent {agent_name} at {agent_server_origin}")
    httpx_client = await get_client(agent_server_origin)
    headers = [("Content-Type", "application/json")]
    session_request_url = (
        f"{agent_server_origin}/apps/{agent_name}/users/{user_id}/sessions"
    )
    session_response = await httpx_client.post(session_request_url, headers=headers)
    session_response.raise_for_status()
    return session_response.json()


async def get_session(
    agent_server_origin: str, agent_name: str, user_id: str, session_id: str
) -> dict[str, Any] | None:
    logger.info(f"Fetching session {session_id} for agent {agent_name} at {agent_server_origin}")
    httpx_client = await get_client(agent_server_origin)
    headers = [("Content-Type", "application/json")]
    session_request_url = (
        f"{agent_server_origin}/apps/{agent_name}/users/{user_id}/sessions/{session_id}"
    )
    session_response = await httpx_client.get(session_request_url, headers=headers)
    if session_response.status_code == 404:
        return None
    session_response.raise_for_status()
    return session_response.json()


async def list_agents(agent_server_origin: str) -> list[str]:
    logger.info(f"Listing agents at {agent_server_origin}")
    httpx_client = await get_client(agent_server_origin)
    headers = [("Content-Type", "application/json")]
    list_url = f"{agent_server_origin}/list-apps"
    list_response = await httpx_client.get(list_url, headers=headers)
    list_response.raise_for_status()
    agent_list = list_response.json()
    if not agent_list:
        agent_list = ["agent"]
    return agent_list


async def query_adk_server(
    agent_server_origin: str,
    agent_name: str,
    user_id: str,
    message: str,
    session_id: str,
) -> AsyncGenerator[dict[str, Any]]:
    httpx_client = await get_client(agent_server_origin)
    request = {
        "appName": agent_name,
        "userId": user_id,
        "sessionId": session_id,
        "newMessage": {"role": "user", "parts": [{"text": message}]},
        "streaming": True,
    }
    logger.info(
        f"Connecting to ADK server: {agent_server_origin}/run_sse with streaming=True"
    )
    try:
        async with aconnect_sse(
            httpx_client, "POST", f"{agent_server_origin}/run_sse", json=request
        ) as event_source:
            if event_source.response.status_code != 200:
                await event_source.response.aread()
                logger.error(
                    f"Error from agent server: {event_source.response.status_code} - {event_source.response.text}"
                )
                yield {
                    "author": agent_name,
                    "content": {
                        "parts": [
                            {
                                "text": f"❌ Server Error: {event_source.response.status_code}"
                            }
                        ]
                    },
                }
                return

            async for server_event in event_source.aiter_sse():
                try:
                    event = server_event.json()
                    yield event
                except Exception as e:
                    logger.error(f"Failed to parse SSE event: {e}")
    except Exception as e:
        logger.error(f"SSE connection failed: {e}")
        yield {
            "author": agent_name,
            "content": {"parts": [{"text": f"❌ Connection Failed: {e}"}]},
        }


def extract_all_text(event_obj: dict[str, Any]) -> list[str]:
    """Targeted extraction of text from ADK event content parts."""
    if not isinstance(event_obj, dict):
        return []
    texts = []
    content = event_obj.get("content")
    if isinstance(content, dict):
        parts = content.get("parts")
        if isinstance(parts, list):
            for part in parts:
                if isinstance(part, dict) and "text" in part:
                    texts.append(part["text"])
    return texts


def merge_strings(existing: str, incoming: str) -> str:
    """A truly robust greedy overlap deduplicator."""
    if not existing:
        return incoming
    if not incoming:
        return existing
    e_norm = existing.rstrip()
    i_norm = incoming.lstrip()
    if not i_norm:
        return existing
    max_overlap = min(len(e_norm), len(i_norm), 500)
    for size in range(max_overlap, 0, -1):
        if e_norm.endswith(i_norm[:size]):
            norm_prefix = i_norm[:size]
            idx = incoming.find(norm_prefix)
            return existing + incoming[idx + size :]
    return existing + incoming


def cleanup_final_text(text: str) -> str:
    """Surgical cleanup for known progress messages or system leaks."""
    # Remove progress messages
    text = re.sub(r"🚀\s*Starting the course creation pipeline\.\.\.", "", text)
    text = re.sub(r"✍️\s*Building the final course content\.\.\.", "", text)
    text = re.sub(r"🔍\s*Research is starting\.\.\.", "", text)
    text = re.sub(r"⚖️\s*Judge is evaluating findings\.\.\.", "", text)

    # Remove system author markers if any leaked
    text = re.sub(r"\[progress_.*\]\s*said:?", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\[capture_.*\]\s*said:?", "", text, flags=re.IGNORECASE)
    text = re.sub(r"For context:?", "", text, flags=re.IGNORECASE)

    # Remove finding markers if they leaked
    text = text.replace("RESEARCH_FINDINGS_START", "").replace(
        "RESEARCH_FINDINGS_END", ""
    )

    return text.strip()


class SimpleChatRequest(BaseModel):
    message: str
    user_id: str = "test_user"
    session_id: str | None = None


@app.post("/api/chat_stream")
async def chat_stream(request: SimpleChatRequest):
    """Streaming chat endpoint."""
    global agent_name, agent_server_url
    logger.info(f"Received chat_stream request for topic: {request.message}")

    async def event_generator():
        nonlocal agent_name
        final_text = ""
        
        # Initial heartbeat - send immediately
        yield (
            json.dumps(
                {
                    "type": "progress",
                    "text": "🚀 Connecting to AI squad...",
                }
            )
            + "\n"
        )

        if not agent_server_url:
            logger.error("AGENT_SERVER_URL environment variable not set")
            yield json.dumps({"type": "progress", "text": "❌ Configuration Error: AGENT_SERVER_URL not set"}) + "\n"
            return

        # Always fetch current agent name from server to be safe
        try:
            logger.info("Fetching agent list from orchestrator...")
            agents = await list_agents(agent_server_url)
            env_agent_name = os.getenv("AGENT_NAME")
            if env_agent_name and env_agent_name in agents:
                agent_name = env_agent_name
            else:
                agent_name = agents[0]
            logger.info(f"Using agent: {agent_name}")
            yield json.dumps({"type": "progress", "text": f"🤖 Agent {agent_name} ready..."}) + "\n"
        except Exception as e:
            logger.error(f"Failed to list agents: {e}")
            logger.error(traceback.format_exc())
            yield json.dumps({"type": "progress", "text": f"⚠️ Warning: Could not list agents ({e}). Using default."}) + "\n"
            if not agent_name:
                agent_name = "orchestrator"  # fallback

        try:
            session = None
            if request.session_id:
                logger.info(f"Attempting to reuse session: {request.session_id}")
                session = await get_session(
                    agent_server_url,
                    agent_name,
                    request.user_id,
                    request.session_id,
                )
            if session is None:
                logger.info("Creating new session...")
                session = await create_session(
                    agent_server_url,
                    agent_name,
                    request.user_id,
                )
            
            logger.info(f"Starting event generator for session {session['id']}")
            yield json.dumps({"type": "progress", "text": "📡 Session established, starting research..."}) + "\n"

            events = query_adk_server(
                agent_server_url,
                agent_name,
                request.user_id,
                request.message,
                session["id"],
            )

            async for event in events:
                author = event.get("author", "")

                # Check for errors
                error_msg = event.get("errorMessage")
                if error_msg:
                    logger.error(f"Error event from {author}: {error_msg}")
                    yield (
                        json.dumps(
                            {
                                "type": "progress",
                                "text": f"❌ Error from {author}: {error_msg}",
                            }
                        )
                        + "\n"
                    )
                    continue

                # Extract text parts helper
                text_parts = extract_all_text(event)
                event_text = "".join(text_parts)
                if not event_text:
                    continue

                # 1. Handle explicit progress agents
                if author.startswith("progress_"):
                    yield (
                        json.dumps({"type": "progress", "text": event_text.strip()}) + "\n"
                    )
                    continue

                # 2. UI Updates for main agents
                if author == "researcher":
                    yield (
                        json.dumps(
                            {
                                "type": "progress",
                                "text": "🔍 Researcher is gathering information...",
                            }
                        )
                        + "\n"
                    )
                elif author == "judge":
                    yield (
                        json.dumps(
                            {
                                "type": "progress",
                                "text": "⚖️ Judge is evaluating findings...",
                            }
                        )
                        + "\n"
                    )
                elif author == "content_builder":
                    yield (
                        json.dumps(
                            {
                                "type": "progress",
                                "text": "✍️ Content Builder is writing the course...",
                            }
                        )
                        + "\n"
                    )

                # 3. Robust Accumulation for final_text (Content Builder ONLY)
                if author == "content_builder":
                    final_text = merge_strings(final_text, event_text)

            logger.info(f"Stream complete. Final text length: {len(final_text)}")

            # Final cleanup and trim
            final_text = cleanup_final_text(final_text)

            # Send final result
            yield json.dumps({"type": "result", "text": final_text}) + "\n"
            
        except Exception as e:
            logger.error(f"Error in event_generator: {e}")
            logger.error(traceback.format_exc())
            yield json.dumps({"type": "progress", "text": f"❌ Critical Error: {e}"}) + "\n"

    return StreamingResponse(event_generator(), media_type="application/x-ndjson")


@app.get("/health")
async def health():
    return {"status": "ok"}


# Mount frontend from the Vite build directory
frontend_path = os.path.join(os.path.dirname(__file__), "dist")
if not os.path.exists(frontend_path):
    # For local development we might not have dist, but for production we MUST
    if os.getenv("DEPLOYMENT_ENV") == "production":
        raise RuntimeError(
            f"Frontend directory not found at {frontend_path}. Check Docker build."
        )
    else:
        print(f"Warning: Frontend directory not found at {frontend_path}")
else:
    app.mount("/", StaticFiles(directory=frontend_path, html=True), name="frontend")

if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", 8080))
    print(f"Starting server on port {port}")
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        log_config=get_uvicorn_log_config(os.getenv("LOG_LEVEL", "info")),
    )
