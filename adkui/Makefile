# Makefile for ADK Comic Pipeline

.PHONY: clean test deploy run endpoint

clean:
	@echo "Cleaning up generated images and temporary files..."
	find . -name "*.log" -delete 2>/dev/null || true
	find images -name "*.png" -delete 2>/dev/null || true
	find output/images -name "*.png" -delete 2>/dev/null || true
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name ".adk" -exec rm -rf {} +
	@echo "Clean completed."


deploy:
	./deploy-lightsail.sh

deploy-lightsail:
	./deploy-lightsail.sh

lightsail-status:
	@aws lightsail get-container-services --service-name biometric-scout-service --region us-east-1 \
		--query 'containerServices[0].{State:state, Deployment:currentDeployment.state, URL:publicEndpoint.url}' \
		--output table
