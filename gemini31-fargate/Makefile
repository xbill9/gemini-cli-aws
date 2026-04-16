export AWS_PAGER :=
# Makefile for Alpha Rescue Drone - Biometric Security System (Mission Alpha)

# Variables
CLUSTER_NAME = biometric-scout-cluster
SERVICE_NAME = biometric-scout-service
REGION = us-east-1

.PHONY: clean test lint deploy run status fargate-status endpoint aws-destroy frontend mock run-mock frontend-dev setup help

help:
	@echo "Available targets:"
	@echo "  setup         - Initialize environment and install dependencies"
	@echo "  run           - Start the backend agent (ADK)"
	@echo "  frontend      - Build the frontend production assets"
	@echo "  frontend-dev  - Start the frontend development server"
	@echo "  mock          - Start the mock backend server"
	@echo "  test          - Run all backend and connectivity tests"
	@echo "  lint          - Run linting (Ruff for Python, ESLint for Frontend)"
	@echo "  deploy        - Full AWS Fargate deployment"
	@echo "  status        - Check Fargate cluster and service status"
	@echo "  endpoint      - Get the public HTTPS endpoint"
	@echo "  aws-destroy   - Clean up all AWS resources"
	@echo "  clean         - Remove temporary files and caches"

setup:
	./init.sh
	./frontend.sh

run:
	./runadk.sh

run-mock: mock

frontend-dev:
	cd frontend && npm run dev

clean:
	@echo "Cleaning up generated images and temporary files..."
	find . -name "*.log" -delete 2>/dev/null || true
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name ".adk" -exec rm -rf {} +
	rm -rf frontend/dist
	@echo "Clean completed."

frontend:
	cd frontend && npm install && npm run build

mock:
	python mock/mock_server.py

test:
	@echo "Running backend and connectivity tests..."
	python3 -m pytest test_live_connection.py test_ws_backend.py test_ws_backend_v2.py backend/app/biometric_agent/test_agent.py

lint:
	@echo "Linting Python code with Ruff..."
	ruff check backend
	@echo "Linting Frontend code with ESLint..."
	cd frontend && npm run lint

deploy:
	./save-aws-creds.sh
	./deploy-fargate.sh

deploy-fargate:
	./deploy-fargate.sh

fargate-status:
	@echo "--- Fargate Cluster Status ---"
	@aws ecs describe-clusters --clusters $(CLUSTER_NAME) --region $(REGION) \
		--query 'clusters[0].{Name:clusterName, Status:status, Running:runningTasksCount, Pending:pendingTasksCount}' \
		--output table 2>/dev/null || echo "No Fargate cluster found."
	@echo "--- Fargate Service Status ---"
	@aws ecs describe-services --cluster $(CLUSTER_NAME) --services $(SERVICE_NAME) --region $(REGION) \
		--query 'services[0].{Service:serviceName, Status:status, Desired:desiredCount, Running:runningCount}' \
		--output table 2>/dev/null || echo "No Fargate service found."

endpoint:
	@echo "--- Fargate HTTPS Endpoint ---"
	@ALB_DNS=$$(aws elbv2 describe-load-balancers --names biometric-scout-alb --region $(REGION) --query "LoadBalancers[0].DNSName" --output text 2>/dev/null); \
	if [ -z "$$ALB_DNS" ] || [ "$$ALB_DNS" = "None" ]; then echo "ALB not found. Deployment may not be complete."; exit 1; fi; \
	echo "Application URL: https://$$ALB_DNS"

status: fargate-status

aws-destroy:
	@echo "Destroying AWS resources for gemini31-fargate..."
	@echo "Stopping and deleting ECS service..."
	@aws ecs update-service --cluster $(CLUSTER_NAME) --service $(SERVICE_NAME) --desired-count 0 --region $(REGION) 2>/dev/null || true
	@aws ecs delete-service --cluster $(CLUSTER_NAME) --service $(SERVICE_NAME) --force --region $(REGION) 2>/dev/null || true
	@echo "Deleting ECS cluster..."
	@aws ecs delete-cluster --cluster $(CLUSTER_NAME) --region $(REGION) 2>/dev/null || true
	@echo "Deleting ECR repository..."
	@aws ecr delete-repository --repository-name biometric-scout-image --region $(REGION) --force 2>/dev/null || true
	@echo "Cleaning up ALB and networking..."
	@ALB_ARN=$$(aws elbv2 describe-load-balancers --names biometric-scout-alb --region $(REGION) --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null); \
	if [ -n "$$ALB_ARN" ] && [ "$$ALB_ARN" != "None" ]; then \
		echo "Deleting Load Balancer $$ALB_ARN..."; \
		aws elbv2 delete-load-balancer --load-balancer-arn $$ALB_ARN --region $(REGION) 2>/dev/null || true; \
		echo "Waiting for ALB deletion..."; \
		aws elbv2 wait load-balancers-deleted --load-balancer-arns $$ALB_ARN --region $(REGION) 2>/dev/null || true; \
	fi
	@TG_ARN=$$(aws elbv2 describe-target-groups --names biometric-scout-tg --region $(REGION) --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null); \
	if [ -n "$$TG_ARN" ] && [ "$$TG_ARN" != "None" ]; then \
		echo "Deleting Target Group $$TG_ARN..."; \
		aws elbv2 delete-target-group --target-group-arn $$TG_ARN --region $(REGION) 2>/dev/null || true; \
	fi
	@echo "Deleting Security Groups..."
	@aws ec2 delete-security-group --group-name fargate-task-sg --region $(REGION) 2>/dev/null || true
	@aws ec2 delete-security-group --group-name alb-sg --region $(REGION) 2>/dev/null || true
	@echo "AWS resources destroyed."
