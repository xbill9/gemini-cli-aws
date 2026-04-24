# AI Course Creator (Distributed Multi-Agent System - AWS Lambda Stack)

A multi-agent system built with Google's Agent Development Kit (ADK) and Agent-to-Agent (A2A) protocol, deployed on **AWS Lambda** as a unified container stack. It features a team of specialized microservice agents that research, judge, and build content, orchestrated to deliver high-quality educational modules.

## Architecture

This project uses a distributed microservices architecture where all services are deployed from a **single unified container image** to AWS Lambda:

*   **Course Builder Gateway (`app/`):** The **External Gateway** for the system. It serves the Vanilla TypeScript + Vite frontend and provides the FastAPI backend that orchestrates the streaming process.
*   **Orchestrator Service (`agents/orchestrator`):** Manages the overall course creation pipeline. It implements an iterative Research-Judge loop using specialized ADK agents.
*   **Researcher Service (`agents/researcher`):** Gathers detailed topic information using the `google_search` tool.
*   **Judge Service (`agents/judge`):** Evaluates research quality.
*   **Content Builder Agent (`agents/content_builder`):** Compiles validated research into professional Markdown modules.

## Project Structure

```
multi-lambda/
├── Dockerfile            # Unified stack image for all services
├── agents/
│   ├── orchestrator/     # Workflow management
│   ├── researcher/       # Information gathering
│   ├── judge/            # Quality control
│   └── content_builder/  # Content generation (Markdown)
├── app/                  # Gateway (FastAPI + Frontend)
├── shared/               # Shared utilities
├── lambda/               # AWS Lambda stack deployment scripts
├── Makefile              # Development shortcuts (make deploy-lambda)
└── *_test.sh             # Agent-specific testing scripts
```

## Requirements

*   **Python 3.13+**
*   **Node.js & npm**: For frontend development and builds.
*   **Docker**: For building and pushing images.
*   **AWS CLI**: For managing AWS resources.
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

4.  **Deploy to AWS Lambda:**
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

# Test remote Lambda environment
make e2e-test-lambda
```

## Deployment to AWS Lambda

The system can be deployed to **AWS Lambda** using the following commands:

1.  **Configure AWS:**
    ```bash
    aws configure
    ```

2.  **Run Deployment:**
    ```bash
    make deploy-lambda
    ```
    This script handles ECR repository creation, image building/pushing, and Lambda function creation/update with Function URLs.

3.  **Check Status:**
    ```bash
    make lambda-status
    ```

4.  **Get Endpoint:**
    ```bash
    make endpoint-lambda
    ```

## Recommended Models

*   **Primary:** `gemini-2.5-flash` (Recommended) for superior reasoning, tool-calling accuracy, and cost-effectiveness.
*   **Alternative:** `gemini-2.5-pro` for tasks requiring even deeper reasoning or complex instruction following.
*   **Note:** Do not use models less than 2.5 (e.g., 2.0 Flash) as they are deprecated.
