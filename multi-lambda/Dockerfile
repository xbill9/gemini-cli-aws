# Unified Dockerfile for AI Course Creator (Multi-Agent System)
# This single image can run the App Gateway, Orchestrator, or any Sub-Agent.

FROM node:23-slim AS frontend-builder
WORKDIR /build
COPY app/frontend/package*.json ./
RUN npm install
COPY app/frontend/ ./
RUN npm run build

FROM python:3.13-slim-bookworm

# Install minimal system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install AWS Lambda Web Adapter
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.9.0 /lambda-adapter /opt/extensions/lambda-adapter
ENV PORT=8080

WORKDIR /app

# Copy root requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all source code
COPY shared/ ./shared/
COPY agents/ ./agents/
COPY app/ ./app/

# Copy built frontend
COPY --from=frontend-builder /dist ./app/dist

# Install the sub-packages in editable mode or just ensure they are in PYTHONPATH
ENV PYTHONPATH=/app:/app/app:/app/agents

# Default command (can be overridden by Lambda)
# Gateway: python app/main.py
# Agent: python -m shared.adk_app --host 0.0.0.0 --port 8080 --a2a agents/researcher
CMD ["python", "app/main.py"]
