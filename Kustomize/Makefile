# Kustomize Multi-Environment Management Makefile
#
# This Makefile automates common operations for managing Kubernetes deployments
# across development and UAT environments using Kustomize and Traefik.
#
# Usage:
#   make setup-traefik    # Install Traefik ingress controller
#   make dev-up          # Deploy development environment
#   make dev-down        # Teardown development environment
#   make uat-up          # Deploy UAT environment
#   make uat-down        # Teardown UAT environment
#   make port-forward    # Start port forwarding (blocking)
#   make add-hosts       # Add hostnames to /etc/hosts
#   make clean-hosts     # Remove hostnames from /etc/hosts
#   make status          # Check status of all resources
#   make clean-all       # Complete cleanup

.PHONY: help setup-traefik dev-up dev-down uat-up uat-down port-forward add-hosts clean-hosts status clean-all

# Default target
help:
	@echo "Kustomize Multi-Environment Management"
	@echo "====================================="
	@echo ""
	@echo "Available targets:"
	@echo "  setup-traefik    Install Traefik ingress controller"
	@echo "  dev-up          Deploy development environment"
	@echo "  dev-down        Teardown development environment"
	@echo "  uat-up          Deploy UAT environment"
	@echo "  uat-down        Teardown UAT environment"
	@echo "  port-forward    Start port forwarding to Traefik (blocking)"
	@echo "  add-hosts       Add hostnames to /etc/hosts"
	@echo "  clean-hosts     Remove hostnames from /etc/hosts"
	@echo "  status          Check status of all resources"
	@echo "  clean-all       Complete cleanup of everything"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make setup-traefik"
	@echo "  2. make add-hosts"
	@echo "  3. make dev-up"
	@echo "  4. make port-forward (in another terminal)"
	@echo "  5. Visit http://dev-nginx.localhost:8080"

# Variables
TRAEFIK_NAMESPACE = traefik
TRAEFIK_CHART = traefik/traefik
TRAEFIK_VALUES = traefik-values.yaml

# Setup Traefik ingress controller
setup-traefik:
	@echo "🚀 Setting up Traefik ingress controller..."
	@echo "Creating Traefik namespace..."
	kubectl create namespace $(TRAEFIK_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@echo "Adding Traefik Helm repository..."
	helm repo add traefik https://traefik.github.io/charts
	helm repo update
	@echo "Installing Traefik..."
	helm upgrade --install traefik $(TRAEFIK_CHART) \
		--namespace $(TRAEFIK_NAMESPACE) \
		--values $(TRAEFIK_VALUES) \
		--wait
	@echo "✅ Traefik installation complete!"
	@echo "Verifying installation..."
	kubectl get pods -n $(TRAEFIK_NAMESPACE)

# Deploy development environment
dev-up:
	@echo "🔧 Deploying development environment..."
	kubectl apply -k overlays/dev
	@echo "✅ Development environment deployed!"
	@echo "Checking pod status..."
	kubectl get pods -l environment=dev
	@echo ""
	@echo "📋 Next steps:"
	@echo "  1. Run 'make port-forward' in another terminal"
	@echo "  2. Visit http://dev-nginx.localhost:8080"

# Teardown development environment
dev-down:
	@echo "🗑️  Tearing down development environment..."
	kubectl delete -k overlays/dev
	@echo "✅ Development environment removed!"

# Deploy UAT environment
uat-up:
	@echo "🔧 Deploying UAT environment..."
	kubectl apply -k overlays/uat
	@echo "✅ UAT environment deployed!"
	@echo "Checking pod status..."
	kubectl get pods -l environment=uat
	@echo ""
	@echo "📋 Next steps:"
	@echo "  1. Run 'make port-forward' in another terminal"
	@echo "  2. Visit http://uat-nginx.example.com:8080"

# Teardown UAT environment
uat-down:
	@echo "🗑️  Tearing down UAT environment..."
	kubectl delete -k overlays/uat
	@echo "✅ UAT environment removed!"

# Start port forwarding (blocking operation)
port-forward:
	@echo "🔗 Starting port forwarding to Traefik..."
	@echo "This will forward localhost:8080 to Traefik service"
	@echo "Keep this terminal open and use Ctrl+C to stop"
	@echo "Access your services at:"
	@echo "  Dev: http://dev-nginx.localhost:8080"
	@echo "  UAT: http://uat-nginx.example.com:8080"
	@echo ""
	kubectl port-forward -n $(TRAEFIK_NAMESPACE) svc/traefik 8080:80

# Add hostnames to /etc/hosts
add-hosts:
	@echo "📝 Adding hostnames to /etc/hosts..."
	@echo "This requires sudo privileges"
	@echo "127.0.0.1 dev-nginx.localhost" | sudo tee -a /etc/hosts
	@echo "127.0.0.1 uat-nginx.example.com" | sudo tee -a /etc/hosts
	@echo "✅ Hostnames added!"
	@echo "You can now access:"
	@echo "  Dev: http://dev-nginx.localhost:8080"
	@echo "  UAT: http://uat-nginx.example.com:8080"

# Remove hostnames from /etc/hosts
clean-hosts:
	@echo "🧹 Removing hostnames from /etc/hosts..."
	@echo "This requires sudo privileges"
	sudo sed -i '' '/dev-nginx.localhost/d' /etc/hosts
	sudo sed -i '' '/uat-nginx.example.com/d' /etc/hosts
	@echo "✅ Hostnames removed!"

# Check status of all resources
status:
	@echo "📊 Checking status of all resources..."
	@echo ""
	@echo "=== Traefik Status ==="
	kubectl get pods,svc -n $(TRAEFIK_NAMESPACE)
	@echo ""
	@echo "=== Application Pods ==="
	kubectl get pods
	@echo ""
	@echo "=== Services ==="
	kubectl get svc
	@echo ""
	@echo "=== IngressRoutes ==="
	kubectl get ingressroute
	@echo ""
	@echo "=== Endpoints ==="
	kubectl get endpoints

# Preview what would be deployed (without applying)
preview-dev:
	@echo "👀 Previewing development environment configuration..."
	kubectl kustomize overlays/dev

preview-uat:
	@echo "👀 Previewing UAT environment configuration..."
	kubectl kustomize overlays/uat

# Check logs
logs-dev:
	@echo "📋 Development environment logs..."
	kubectl logs -l environment=dev --tail=50

logs-uat:
	@echo "📋 UAT environment logs..."
	kubectl logs -l environment=uat --tail=50

logs-traefik:
	@echo "📋 Traefik logs..."
	kubectl logs -n $(TRAEFIK_NAMESPACE) deployment/traefik --tail=50

# Complete cleanup
clean-all: dev-down uat-down clean-hosts
	@echo "🧹 Performing complete cleanup..."
	@echo "Removing Traefik..."
	helm uninstall traefik -n $(TRAEFIK_NAMESPACE) --ignore-not-found
	kubectl delete namespace $(TRAEFIK_NAMESPACE) --ignore-not-found
	@echo "✅ Complete cleanup finished!"

# Development workflow shortcuts
dev-cycle: dev-down dev-up
	@echo "🔄 Development cycle complete!"

uat-cycle: uat-down uat-up
	@echo "🔄 UAT cycle complete!"

# Quick setup for new environments
quick-dev: setup-traefik add-hosts dev-up
	@echo "🚀 Quick development setup complete!"
	@echo "Run 'make port-forward' in another terminal to access your application"

quick-uat: setup-traefik add-hosts uat-up
	@echo "🚀 Quick UAT setup complete!"
	@echo "Run 'make port-forward' in another terminal to access your application"

# Troubleshooting helpers
debug-dev:
	@echo "🔍 Debugging development environment..."
	@echo ""
	@echo "=== Pod Status ==="
	kubectl get pods -l environment=dev -o wide
	@echo ""
	@echo "=== Pod Describe ==="
	kubectl describe pods -l environment=dev
	@echo ""
	@echo "=== Service Endpoints ==="
	kubectl get endpoints dev-nginx -o wide
	@echo ""
	@echo "=== IngressRoute Details ==="
	kubectl describe ingressroute dev-nginx-test

debug-uat:
	@echo "🔍 Debugging UAT environment..."
	@echo ""
	@echo "=== Pod Status ==="
	kubectl get pods -l environment=uat -o wide
	@echo ""
	@echo "=== Pod Describe ==="
	kubectl describe pods -l environment=uat
	@echo ""
	@echo "=== Service Endpoints ==="
	kubectl get endpoints uat-nginx -o wide
	@echo ""
	@echo "=== IngressRoute Details ==="
	kubectl describe ingressroute uat-nginx-test

# Validation targets
validate:
	@echo "✅ Validating Kustomize configurations..."
	@echo "Validating dev overlay..."
	kubectl kustomize overlays/dev > /dev/null && echo "  ✅ Dev overlay is valid"
	@echo "Validating uat overlay..."
	kubectl kustomize overlays/uat > /dev/null && echo "  ✅ UAT overlay is valid"
	@echo "All configurations are valid!"

# Show current context and cluster info
info:
	@echo "📋 Current Kubernetes context and cluster information..."
	@echo ""
	@echo "=== Context ==="
	kubectl config current-context
	@echo ""
	@echo "=== Cluster Info ==="
	kubectl cluster-info
	@echo ""
	@echo "=== Node Status ==="
	kubectl get nodes 