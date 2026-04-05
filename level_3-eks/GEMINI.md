# Gemini Code Assistant Context: Mission Alpha (EKS Edition)

This document provides context for the Gemini Code Assistant to understand the **Mission Alpha: Biometric Scout** project, a gamified biometric authentication system using Google ADK and Gemini Live, specifically configured for **AWS EKS Deployment**.

## Project Overview

"Mission Alpha" implements a real-time biometric scanner that verifies hand gestures (counting fingers 1-5) to bypass a simulated security firewall. It leverages the **Google ADK** to manage bidirectional streaming between a React frontend and the **Gemini Live API**.

*   **App Name**: `alpha-drone` (as seen in `/health` response).
*   **Target Port**: 8080 (container), 443 (LoadBalancer).

## Key Technologies

*   **Framework:** Google ADK (Agent Development Kit)
*   **Backend:** Python 3, FastAPI (Uvicorn with SSL support).
*   **Frontend:** React (Vite, Tailwind CSS) for a cyberpunk HUD.
*   **Infrastructure:** AWS EKS (Elastic Kubernetes Service).
*   **Generative AI:** Gemini Live API via Vertex AI or Google AI SDK.
*   **Deployment:** Docker + ECR + EKS.
*   **Networking:** HTTPS (SSL via ACM on AWS Load Balancer or local certs).

## Deployment (EKS Only)

The project is optimized for deployment on AWS EKS.

*   **`deploy-eks.sh`**: Main deployment script that builds the image, pushes to ECR, and applies K8s manifests.
*   **`save-aws-creds.sh`**: Helper script used by the Makefile to export active AWS credentials to `.aws_creds`.
*   **`k8s-deployment.yaml.template`**: Template for Kubernetes resources, including a LoadBalancer with ACM SSL certificate integration (`arn:aws:acm:us-east-1:106059658660:certificate/...`).
*   **`eks-cluster.yaml`**: Configuration for creating the EKS cluster via `eksctl`.

## HTTPS Implementation

*   **Backend**: `backend/app/main.py` detects `cert.pem`/`key.pem` for local HTTPS. In EKS, SSL is terminated at the AWS LoadBalancer.
*   **Frontend**: `frontend/src/BiometricLock.jsx` dynamically switches between `ws://` and `wss://`.
*   **AWS**: The LoadBalancer (ELB) handles SSL using ACM.

## Health and Validation

*   **Endpoint**: `/health`
*   **Payload**: `{"status":"ok","app":"alpha-drone"}`
*   **Verification**: `curl -k https://<elb-hostname>/health`

## Makefile Commands

*   `make deploy`: Full deployment cycle (ECR push + EKS update).
*   `make status`: Check EKS pods and service status.
*   `make endpoint`: Retrieve the public LoadBalancer hostname.
*   `make eks-destroy`: Remove K8s deployment and service.
*   `make frontend`: Rebuild the frontend distribution.
*   `make clean`: Purge cache and build artifacts.

## Workflow

1.  **User Trigger**: User clicks "Initiate Neural Sync" on the React HUD.
2.  **HTTPS Connection**: Frontend establishes a secure connection to the FastAPI backend.
3.  **Bidirectional Stream**: Secure WebSocket (WSS) manages real-time video/audio streaming.
4.  **Agent Analysis**: `biometric_agent` uses Gemini Live to analyze frames for finger counts.
5.  **Sequence Validation**: Frontend validates detected digits against a randomized 4-digit sequence.
6.  **Success**: Access granted if the sequence is completed within the timer.
