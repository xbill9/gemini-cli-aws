# Use a standard Python slim image
FROM python:3.13-slim

# Set the working directory
WORKDIR /app

# Copy requirements.txt and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY main.py .

# Set the PORT environment variable
ENV PORT=8080

# Expose the port
EXPOSE 8080

# Run the Starlette app via uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
