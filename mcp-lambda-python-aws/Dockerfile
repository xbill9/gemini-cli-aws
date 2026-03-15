# Use a standard Python slim image
FROM python:3.13-slim

# 1. Install the AWS Lambda Web Adapter
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 /lambda-adapter /opt/extensions/lambda-adapter

# Set the working directory
WORKDIR /var/task

# Copy requirements.txt and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY main.py .

# Set the PORT environment variable for the web adapter
ENV PORT=8080
ENV AWS_LAMBDA_WEB_ADAPTER_INVOKE_MODE=buffered

# The Web Adapter will start the process and forward requests to PORT
# We use uvicorn to run the Starlette app
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
