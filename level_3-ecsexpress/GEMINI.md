# Gemini Code Assistant Context: Mission Alpha

This document provides context for the Gemini Code Assistant to understand the **Mission Alpha: Biometric Scout** project, a gamified biometric authentication system using Google ADK and Gemini Live.

## Project Overview

"Mission Alpha" implements a real-time biometric scanner that verifies hand gestures (counting fingers 1-5) to bypass a simulated security firewall. It leverages the **Google ADK** to manage bidirectional streaming between a React frontend and the **Gemini Live API**.

## Key Technologies

*   **Framework:** Google ADK (Agent Development Kit) [Docs](https://google.github.io/adk-docs/)
*   **Backend:** Python 3, FastAPI, Uvicorn (port 8080).
*   **Frontend:** React (Vite, Tailwind CSS, Lucide icons) for a cyberpunk HUD.
*   **Generative AI:** Gemini Live API via Vertex AI or Google AI SDK.
*   **Cloud Platforms:** Google Cloud (Vertex AI), AWS (ECS Express Mode).
*   **Model:** `gemini-2.5-flash-native-audio-preview-12-2025` (Optimized for real-time video/audio).
*   **Environment:** `.env` for API keys, project IDs, and model configuration.

## Project Structure

*   **`backend/app/`**:
    *   `main.py`: FastAPI server handling WebSockets, session management, and ADK runner.
    *   **`biometric_agent/`**:
        *   `agent.py`: Agent definition with instructions for counting fingers and tool definitions.
*   **`frontend/`**:
    *   `src/BiometricLock.jsx`: Main UI component for the "Neural Handshake" challenge.
    *   `src/useGeminiSocket.js`: WebSocket hook managing camera/microphone streams and message parsing.
*   **`mock/`**:
    *   `mock_server.py`: Simulation server that sends mock `DIGIT_DETECTED` events.
*   **`scripts/`**:
    *   `init.sh`: Environment setup and dependency installation.
    *   `verify_setup.sh`: Sanity check for API credentials and network connectivity.

## Tools & Scripts

*   **Execution**:
    *   `build.sh`: Compiles the React frontend and prepares the `dist/` directory.
    *   `runadk.sh`: Launches the FastAPI backend.
    *   `frontend.sh`: Starts the frontend in development mode.
    *   `mock.sh`: Runs the mock server for UI/logic validation.
*   **Deployment**:
    *   `Makefile`: Primary entry point for AWS ECS Express Mode deployment.
    *   `deploy-ecs.sh`: Script for ECS deployment automation.
    *   `save-aws-creds.sh`: Refreshes AWS credentials in `.aws_creds`.

## Makefile Commands

*   **ECS Express Mode**:
    *   `make deploy`: Full deployment cycle (ECR push + ECS update).
    *   `make status`: Monitor ECS service state and endpoint.
    *   `make endpoint`: Retrieve the public URL for the deployed service.
    *   `make aws-destroy`: Tear down ECS resources.
*   **General**:
    *   `make frontend`: Rebuild the frontend distribution.
    *   `make clean`: Purge cache, logs, and build artifacts.

## Workflow

1.  **User Trigger**: User clicks "Initiate Neural Sync" on the React HUD.
2.  **Bidirectional Stream**: Frontend starts capturing video/audio and streams it to the FastAPI backend via WebSocket.
3.  **Agent Analysis**: The `biometric_agent` in the backend receives the stream and uses Gemini Live to analyze frames.
4.  **Tool Execution**: When fingers are detected, the agent executes `report_digit(count=N)`.
5.  **HUD Feedback**: The backend relays the tool execution result to the frontend.
6.  **Sequence Validation**: The frontend validates if the detected digit matches the current step in the randomized 4-digit sequence.
7.  **Finality**: If the sequence is completed within the 65-second timer, access is granted.

## Known Bugs & Workarounds

*   **Frontend Caching**: If the UI doesn't update after changes, run `make frontend` to rebuild `dist/`.
*   **Port Conflicts**: Both `runadk.sh` and the frontend may try to use similar ports; `runadk.sh` defaults to 8080.
*   **Model Latency**: Ensure `MODEL_ID` in `.env` points to a "live" or "native-audio" model for optimal performance.
