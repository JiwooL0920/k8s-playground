.PHONY: setup cleanup status logs port-forward help check-deps get-url restart recreate-pod

# Default target when just typing 'make'
.DEFAULT_GOAL := help

# Settings
NAMESPACE := n8n
RELEASE_NAME := n8n
PORT := 5678
LOCAL_PORT := 5678

# Check for required dependencies
check-deps:
	@which kubectl >/dev/null 2>&1 || (echo "Error: kubectl is not installed" && exit 1)
	@which helm >/dev/null 2>&1 || (echo "Error: helm is not installed" && exit 1)
	@which kind >/dev/null 2>&1 || (echo "Error: kind is not installed" && exit 1)

# Setup n8n
setup: check-deps
	@echo "Setting up n8n with SQLite..."
	@chmod +x scripts/setup-n8n.sh
	@./scripts/setup-n8n.sh

# Cleanup n8n
cleanup: check-deps
	@echo "Cleaning up n8n..."
	@chmod +x scripts/cleanup-n8n.sh
	@./scripts/cleanup-n8n.sh

# Check status of n8n pods
status: check-deps
	@echo "Checking status of n8n pods..."
	@kubectl get pods -n $(NAMESPACE)
	@echo "\nService details:"
	@kubectl get svc -n $(NAMESPACE)
	@echo "\nPersistent Volume Claims:"
	@kubectl get pvc -n $(NAMESPACE)

# Get the nodePort and URL to access n8n
get-url: check-deps
	@echo "Getting n8n access URL..."
	@NODE_PORT=$$(kubectl get --namespace $(NAMESPACE) -o jsonpath="{.spec.ports[0].nodePort}" services $(RELEASE_NAME)) && \
	echo "n8n is accessible at: http://localhost:$$NODE_PORT"
	@echo "To use port-forwarding instead: make port-forward"

# Tail logs from n8n
logs: check-deps
	@echo "Showing logs for n8n..."
	@kubectl logs -f deployment/$(RELEASE_NAME) -n $(NAMESPACE)

# Port forward to n8n service
port-forward: check-deps
	@echo "Port forwarding n8n service to localhost:$(LOCAL_PORT)..."
	@kubectl port-forward svc/$(RELEASE_NAME) $(LOCAL_PORT):$(PORT) -n $(NAMESPACE)

# Restart n8n pods
restart: check-deps
	@echo "Restarting n8n pods..."
	@kubectl rollout restart deployment/$(RELEASE_NAME) -n $(NAMESPACE)
	@echo "Waiting for pods to be ready..."
	@kubectl rollout status deployment/$(RELEASE_NAME) -n $(NAMESPACE)

# Delete and recreate the n8n pod (useful for troubleshooting)
recreate-pod: check-deps
	@echo "Recreating n8n pod..."
	@POD_NAME=$$(kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/instance=$(RELEASE_NAME) -o jsonpath='{.items[0].metadata.name}') && \
	if [ -n "$$POD_NAME" ]; then \
		kubectl delete pod $$POD_NAME -n $(NAMESPACE); \
		echo "Pod $$POD_NAME deleted. A new pod will be created automatically."; \
	else \
		echo "No n8n pod found."; \
	fi

# Show help information
help:
	@echo "n8n on Kubernetes Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make setup         - Set up n8n with SQLite"
	@echo "  make cleanup       - Clean up n8n and related resources"
	@echo "  make status        - Check status of n8n pods and services"
	@echo "  make get-url       - Get URL to access n8n"
	@echo "  make logs          - View n8n logs"
	@echo "  make port-forward  - Forward n8n service to localhost"
	@echo "  make restart       - Restart n8n pods"
	@echo "  make recreate-pod  - Delete and recreate the n8n pod"
	@echo "  make help          - Show this help information"
	@echo ""
	@echo "Access n8n at: http://localhost:5678 (with port-forward)" 