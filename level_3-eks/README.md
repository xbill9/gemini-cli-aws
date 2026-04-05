# Mission Alpha: Biometric Scout Agent

This repository contains a gamified biometric authentication system ("Neural Handshake") built using the **Google Agent Development Kit (ADK)** and the **Gemini Live API**. It features a real-time video/audio processing pipeline that verifies hand gestures to bypass a simulated security firewall.

## Features

- **Neural Handshake Protocol**: A time-limited security challenge requiring a specific sequence of finger gestures (1-5 fingers).
- **Real-Time Biometric Analysis**: Uses Gemini Live API's native audio and video capabilities to detect and count fingers in real-time.
- **Futuristic HUD**: A React-based frontend with a cyberpunk aesthetic, featuring scanlines, glitches, and interactive feedback.
- **Scalable Deployment**: Automated scripts for deploying the containerized application to **AWS EKS (Elastic Kubernetes Service)** with integrated SSL support via ACM.
- **Agentic Tool Use**: The Biometric Agent (`biometric_agent`) autonomously executes tools to report detected digits back to the security system.
- **Simulation Mode**: Includes a mock server for testing the UI and logic without calling the live Gemini API.

## Project Structure

- `backend/`: FastAPI application that bridges the frontend WebSocket to the Gemini Live API.
  - `app/main.py`: Entry point for the FastAPI server and WebSocket management.
  - `app/biometric_agent/agent.py`: ADK Agent definition, instructions, and tools.
- `frontend/`: React/Vite/Tailwind application for the "Mission Alpha" HUD.
  - `src/BiometricLock.jsx`: Core game logic and UI components.
  - `src/useGeminiSocket.js`: Custom hook for WebSocket communication.
- `eks-cluster.yaml`: Configuration for creating the EKS cluster using `eksctl`.
- `k8s-deployment.yaml.template`: Kubernetes manifest template for the application and LoadBalancer.
- `mock/`: Python-based mock server that simulates Gemini Live API responses for development.
- `scripts/`: Utility scripts for initialization, verification, and billing.

## Scripts & Utilities

- `build.sh`: High-level script to build the frontend and prepare the environment.
- `deploy-eks.sh`: Main deployment script that builds the image, pushes to ECR, and applies K8s manifests.
- `runadk.sh`: Starts the FastAPI backend server (port 8080).
- `frontend.sh`: Starts the Vite development server for the frontend.
- `mock.sh`: Launches the mock server for local simulation.
- `init.sh`: Comprehensive setup script to install dependencies and configure Cloud projects.
- `save-aws-creds.sh`: Exports and saves AWS credentials for deployment.

## Makefile Commands

- `make clean`: Purges temporary files, cache, and build artifacts.
- `make frontend`: Installs frontend dependencies and builds the production distribution.
- `make deploy`: Full deployment cycle to **AWS EKS** (ECR push + Kubernetes deployment).
- `make status`: Checks the current state of EKS pods and the LoadBalancer service.
- `make endpoint`: Retrieves the public hostname of the AWS LoadBalancer.
- `make eks-destroy`: Tears down the EKS deployment and service.
- `make mock`: Launches the mock server for local simulation.

## How it Works

1.  **Neural Sync Initialization**: The user initiates the handshake from the React HUD.
2.  **Streaming Pipeline**: The frontend captures camera and microphone data, sending it via WebSocket to the FastAPI backend.
3.  **ADK Integration**: The backend uses the Google ADK to pipe the stream to the Gemini Live API.
4.  **Gesture Detection**: The `biometric_agent` monitors the video stream. When it detects a hand gesture, it calls the `report_digit` tool.
5.  **Feedback Loop**: The backend intercepts the tool call, sends a message back to the frontend, and the HUD updates the security sequence progress.
6.  **Validation**: If the user completes the randomized sequence within 65 seconds, "Mission Alpha" access is granted.

## Getting Started

1.  **Initialize Environment**:
    ```bash
    ./init.sh
    ```
2.  **Configure `.env`**:
    Ensure `GOOGLE_CLOUD_PROJECT`, `MODEL_ID`, and `GOOGLE_API_KEY` are set.
3.  **Build and Run**:
    ```bash
    ./build.sh
    ./runadk.sh
    ```
4.  **Access the HUD**:
    Open `http://localhost:8080` in your browser.

## Deployment

### AWS EKS (Recommended)
The project is optimized for AWS EKS. The deployment process is fully automated via the `Makefile`.

1.  **Prepare AWS Credentials**:
    Ensure you have active AWS credentials (e.g., via `aws sso login`).
2.  **Deploy to EKS**:
    ```bash
    make deploy
    ```
    This command will:
    - Save/refresh credentials via `save-aws-creds.sh`.
    - Build and push the Docker image to Amazon ECR.
    - Create or update the EKS cluster (if necessary).
    - Apply Kubernetes manifests (Deployment and LoadBalancer).

3.  **Monitor Status**:
    ```bash
    make status
    ```

4.  **Get Public Endpoint**:
    ```bash
    make endpoint
    ```

> [!NOTE]
> **SSL Certificate**: The EKS LoadBalancer is configured with an ACM certificate. If accessing via the ELB hostname directly, you may see a certificate name mismatch warning. This is expected unless a custom DNS record is mapped to the LoadBalancer.

## Health Check
The application provides a health check endpoint at `/health`:
- **Success Response**: `{"status":"ok","app":"alpha-drone"}`
- **Usage**: Used by Kubernetes liveness and readiness probes.
