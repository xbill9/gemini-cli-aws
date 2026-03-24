# Makefile for ADK Comic Pipeline

# Variables
CLUSTER_NAME = biometric-scout-cluster
SERVICE_NAME = biometric-scout-service
REGION = us-east-1

.PHONY: clean test deploy run status fargate-status endpoint

clean:
	@echo "Cleaning up generated images and temporary files..."
	find . -name "*.log" -delete 2>/dev/null || true
	find images -name "*.png" -delete 2>/dev/null || true
	find output/images -name "*.png" -delete 2>/dev/null || true
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name ".adk" -exec rm -rf {} +
	@echo "Clean completed."

frontend:
	cd frontend && npm install && npm run build

mock:
	python mock/mock_server.py

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
	if [ -z "$$ALB_DNS" ] || [ "$$ALB_DNS" == "None" ]; then echo "ALB not found. Deployment may not be complete."; exit 1; fi; \
	echo "Application URL: https://$$ALB_DNS"

status: fargate-status

