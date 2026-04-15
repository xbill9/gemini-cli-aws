# --- Stage 1: Build Frontend ---
FROM node:25-slim AS frontend-builder
WORKDIR /app/frontend
COPY app/frontend/package*.json ./
RUN npm install
COPY app/frontend/ ./
RUN npm run build

# --- Stage 2: Final Image ---
FROM python:3.13-slim
WORKDIR /app

# Install root dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all source (including shared, agents, app)
COPY . .

# Copy built frontend from Stage 1 into the app's dist directory
COPY --from=frontend-builder /app/dist /app/app/dist

# Copy monolith and web scripts
COPY run_monolith.sh run_web.sh ./
RUN chmod +x run_monolith.sh run_web.sh

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV HOST 0.0.0.0

# Port for ECS Express Mode (default is 8080)
EXPOSE 8080

# Run web script by default (distributed mode)
CMD ["/app/run_web.sh"]
