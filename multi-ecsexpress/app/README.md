# AI Course Creator - Web Application

This directory contains the main web application for the AI Course Creator project. It serves as the frontend for users and orchestrates communication between specialized agents.

## Architecture

The application is built with a decoupled architecture:

*   **Backend:** A FastAPI-based server that handles API requests, manages sessions, and streams real-time updates from agents using Server-Sent Events (SSE).
*   **Frontend:** A modern, single-page application built with Vanilla TypeScript and Vite. It provides a responsive interface for initiating course creation and monitoring progress.
*   **Agent Integration:** Uses the **Agent-to-Agent (A2A)** protocol to communicate with the Orchestrator agent, which in turn manages specialized agents (Researcher, Judge, Content Builder).

## Features

-   **Real-time Streaming:** View the agent's research and decision-making process as it happens.
-   **Structured Course Generation:** Automatically generates high-quality Markdown course modules based on validated research.
-   **Cloud-Native:** Built-in support for OpenTelemetry tracing, JSON logging, and containerized deployment (AWS ECS).

## Development

### Prerequisites

-   Python 3.13+
-   Node.js & npm

### Setup

1.  **Install Dependencies:**
    ```bash
    make install
    ```

2.  **Run Locally:**
    ```bash
    # Start the FastAPI backend and Vite dev server
    make run
    ```
    The application will be available at:
    -   Frontend (Dev): http://localhost:5173
    -   Backend: http://localhost:8000

## Deployment

The application is containerized and ready for deployment to **AWS ECS**.

1.  **Build Frontend:**
    ```bash
    make build-frontend
    ```

2.  **Deploy to ECS:**
    ```bash
    make deploy-ecs
    ```
