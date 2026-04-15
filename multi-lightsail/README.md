# AI Course Creator (Distributed Multi-Agent System - AWS EKS)

A multi-agent system built with Google's Agent Development Kit (ADK) and Agent-to-Agent (A2A) protocol, deployed on **Amazon Elastic Kubernetes Service (EKS)**. It features a team of specialized microservice agents that research, judge, and build content, orchestrated to deliver high-quality educational modules.

## Architecture

This project uses a distributed microservices architecture where each agent runs in its own container and communicates via the A2A protocol:

*   **Orchestrator Service (`agents/orchestrator`):** Manages the overall course creation pipeline using **`SequentialAgent`**. It implements an iterative Research-Judge loop with **`LoopAgent`** (max 2 iterations). Key components include **`TopicCapturer`**, **`EscalationChecker`**, **`ResearchGuard`**, **`StateCapturer`**, and **`ProgressAgent`** for status updates.
*   **Researcher Service (`agents/researcher`):** Gathers detailed topic information using the `google_search` tool.
*   **Judge Service (`agents/judge`):** Evaluates research quality against a Pydantic schema (`JudgeFeedback`).
*   **Content Builder Service (`agents/content_builder`):** Compiles validated research into a professional Markdown course module.
*   **Web App (`app/`):** A FastAPI backend with a Vanilla TypeScript + Vite frontend that streams real-time agent events via SSE.

## Project Structure

```
multi-agent/
├── agents/
│   ├── orchestrator/     # Workflow management & remote agent connections
│   ├── researcher/       # Information gathering (Google Search)
│   ├── judge/            # Quality control (Structured Feedback)
│   └── content_builder/  # Content generation (Markdown)
├── app/                  # Web application (FastAPI + Vanilla TS Frontend)
├── shared/               # Shared utilities (Symlinked into agents)
│   ├── a2a_utils.py      # A2A URL rewriting middleware
│   ├── adk_app.py        # Standardized ADK FastAPI wrapper
│   ├── authenticated_httpx.py # Service-to-service auth utilities
│   └── logging_config.py # Centralized logging configuration
├── eks/                  # AWS EKS deployment manifests and scripts
├── Makefile              # Development shortcuts
├── run_local.sh          # Local development startup script
├── set_env.sh            # Local .env generation script
└── *_test.sh             # Agent-specific testing scripts
```

## Requirements

*   **Python 3.13+**
*   **Node.js & npm**: For frontend development and builds.
*   **Docker**: For building and pushing images.
*   **AWS CLI**: For managing AWS resources.
*   **kubectl**: For interacting with the EKS cluster.
*   **Google API Key**: Required for Gemini.

## Quick Start

1.  **Initialize Environment:**
    ```bash
    # Set up .env
    ./set_env.sh
    ```

2.  **Install Dependencies:**
    ```bash
    # This installs root, agents, app, and frontend dependencies
    make install
    ```

3.  **Run Locally:**
    ```bash
    make run
    ```
    This starts all agents and the web app. The Researcher, Judge, and Content Builder run on ports 8001-8003, the Orchestrator on 8004, and the Web App on 8000.

4.  **Deploy to AWS Lightsail:**
    ```bash
    make deploy
    ```

5.  **Access the App:**
    -   **http://localhost:8000**: Main entry point (FastAPI serving the built frontend).
    -   **http://localhost:5173**: Vite dev server (supports hot-reloading for UI development).

## Testing

### Unit and Agent Tests
Run agent-specific tests to verify individual components:
```bash
./research_test.sh
./judge_test.sh
```
Or run the full suite:
```bash
make test
```

### End-to-End (E2E) Testing
You can run automated E2E tests against the local or remote environment:
```bash
# Test local environment (requires all services running)
make e2e-test

# Test remote EKS environment
make e2e-test-eks
```

## Deployment to AWS Lightsail

The system can be deployed to **AWS Lightsail** using the following commands:

1.  **Configure AWS:**
    ```bash
    aws configure
    ```

2.  **Run Deployment:**
    ```bash
    make deploy-lightsail
    ```
    This script handles ECR repository creation, image building/pushing, and Kubernetes manifest application.

3.  **Check Status:**
    ```bash
    make lightsail-status
    ```

4.  **Get Endpoint:**
    ```bash
    make endpoint-lightsail
    ```

## Deployment to AWS EKS (Advanced)

The system is configured for deployment to **Amazon Elastic Kubernetes Service (EKS)**.

1.  **Configure AWS:**
    ```bash
    aws configure
    ```

2.  **Run Deployment:**
    ```bash
    make deploy-eks
    ```
    This script handles ECR repository creation, image building/pushing, and Kubernetes manifest application.

3.  **Check Status:**
    ```bash
    make status-eks
    ```

4.  **Get Endpoint:**
    ```bash
    make endpoint-eks
    ```

## Recommended Models

*   **Primary:** `gemini-2.5-flash` (Recommended) for superior reasoning, tool-calling accuracy, and cost-effectiveness.
*   **Alternative:** `gemini-2.5-pro` for tasks requiring even deeper reasoning or complex instruction following.
*   **Note:** Do not use models less than 2.5 (e.g., 2.0 Flash) as they are deprecated.
