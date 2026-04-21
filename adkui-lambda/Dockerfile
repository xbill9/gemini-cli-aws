FROM python:3.13-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PORT=8080
# Disable local storage for read-only container environments like Lambda
ENV ADK_DISABLE_LOCAL_STORAGE=1

# 1. Install the AWS Lambda Web Adapter (matching reference version)
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 /lambda-adapter /opt/extensions/lambda-adapter

# Set the working directory to /var/task (Lambda convention)
WORKDIR /var/task

# Install system dependencies (needed for some GenAI operations)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libatomic1 \
    && rm -rf /var/lib/apt/lists/*

# Install uv for fast package management
RUN pip install --no-cache-dir uv

# Copy requirements.txt and install dependencies
COPY requirements.txt .
RUN uv pip install --no-cache-dir --system -r requirements.txt

# Copy the entire project into the container
COPY . .

# Workaround for ADK Web UI read-only filesystem issue
RUN mkdir -p /tmp/config && \
    touch /tmp/config/runtime-config.json && \
    rm -f /usr/local/lib/python3.13/site-packages/google/adk/cli/browser/assets/config/runtime-config.json && \
    ln -s /tmp/config/runtime-config.json /usr/local/lib/python3.13/site-packages/google/adk/cli/browser/assets/config/runtime-config.json

# Set the PORT environment variable for the web adapter
ENV PORT=8080
ENV AWS_LAMBDA_WEB_ADAPTER_INVOKE_MODE=buffered

# Start the ADK Web UI, serving all agents in the current directory
# The Web Adapter will forward requests to this process on port 8080
CMD ["adk", "web", ".", "--host", "0.0.0.0", "--port", "8080", "--no-reload"]
