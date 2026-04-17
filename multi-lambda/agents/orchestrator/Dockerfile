FROM python:3.13-slim
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.9.0 /lambda-adapter /opt/extensions/lambda-adapter

WORKDIR /app

# Copy all source (root context)
COPY . .

# Install shared and agent
RUN pip install --no-cache-dir ./shared
RUN pip install --no-cache-dir ./agents/orchestrator

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV HOST 0.0.0.0

# Run ADK API Server
CMD ["python3", "-m", "shared.adk_app", "/app/agents/orchestrator", "--host", "0.0.0.0", "--a2a"]
