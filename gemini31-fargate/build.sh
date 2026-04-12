#!/bin/bash

# Configuration
SERVICE_NAME="biometric-scout"
IMAGE_NAME="biometric-scout-image"

echo "Building frontend..."
cd frontend && npm install && npm run build && cd ..

echo "Generating Dockerfile..."
cat <<EOF > Dockerfile
FROM node:20-slim as builder

# Set the working directory for our build process
WORKDIR /app

# Copy the frontend's package files first to leverage Docker's layer caching.
COPY frontend/package*.json ./frontend/
# Run 'npm install' from the context of the 'frontend' subdirectory
RUN npm --prefix frontend install

# Copy the rest of the frontend source code
COPY frontend/ ./frontend/
# Run the build script, which will create the 'frontend/dist' directory
RUN npm --prefix frontend run build


# STAGE 2: Build the Python Production Image
FROM python:3.13-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PORT=8080

# Set the final working directory
WORKDIR /app

# Install uv, our fast package manager
RUN pip install uv

# Copy the requirements.txt
COPY requirements.txt .
# Install the Python dependencies
RUN uv pip install --no-cache-dir --system -r requirements.txt

# Copy the contents of your backend application directory
COPY backend/app/ .

# Copy the built frontend assets from the 'builder' stage.
COPY --from=builder /app/frontend/dist /frontend/dist

# Port configuration, defaults to 8080.
EXPOSE 8080

# Set the command to run the application.
CMD ["python", "main.py"]
EOF

echo "Building Docker image locally..."
docker build -t ${IMAGE_NAME}:latest .

echo "Build complete. To deploy to AWS, run: make deploy"
