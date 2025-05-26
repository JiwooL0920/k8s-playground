# Redis Sentinel with Flux - Makefile
# 
# This Makefile provides convenient commands for managing Redis Sentinel 
# deployment using Flux CD and Kustomize overlays.

.PHONY: help install-flux apply-dev apply-prod teardown-dev teardown-prod status logs test clean

# Default target
help: ## Show this help message
	@echo "Redis Sentinel Flux Deployment Commands"
	@echo "========================================"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Environment Variables:"
	@echo "  KUBECONFIG    - Path to kubeconfig file (default: ~/.kube/config)"
	@echo "  NAMESPACE_DEV - Development namespace (default: redis-sentinel-dev)"
	@echo "  NAMESPACE_PROD- Production namespace (default: redis-sentinel-prod)"

# Variables
KUBECONFIG ?= ~/.kube/config
NAMESPACE_DEV ?= redis-sentinel-dev
NAMESPACE_PROD ?= redis-sentinel-prod
FLEET_INFRA_DIR := fleet-infra
DEV_OVERLAY := $(FLEET_INFRA_DIR)/overlays/develop
PROD_OVERLAY := $(FLEET_INFRA_DIR)/overlays/production

# Prerequisites check
check-prerequisites: ## Check if required tools are installed
	@echo "🔍 Checking prerequisites..."
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed"; exit 1; }
	@command -v flux >/dev/null 2>&1 || { echo "❌ flux CLI is required but not installed"; exit 1; }
	@command -v kustomize >/dev/null 2>&1 || echo "⚠️  kustomize not found, using kubectl kustomize"
	@echo "✅ Prerequisites check passed"

check-cluster: ## Verify cluster connectivity
	@echo "🔍 Checking cluster connectivity..."
	@kubectl cluster-info >/dev/null 2>&1 || { echo "❌ Cannot connect to Kubernetes cluster"; exit 1; }
	@echo "✅ Connected to cluster: $$(kubectl config current-context)"

# Flux Installation
install-flux: check-prerequisites check-cluster ## Install Flux controllers
	@echo "🚀 Installing Flux controllers..."
	@flux install --components=source-controller,helm-controller
	@echo "⏳ Waiting for Flux controllers to be ready..."
	@kubectl wait --for=condition=ready pod -l app=helm-controller -n flux-system --timeout=300s
	@kubectl wait --for=condition=ready pod -l app=source-controller -n flux-system --timeout=300s
	@echo "✅ Flux controllers installed and ready"

# Development Environment
check-dev-env: ## Check if development .env file exists
	@if [ ! -f "$(DEV_OVERLAY)/.env" ]; then \
		echo "❌ Missing $(DEV_OVERLAY)/.env file"; \
		echo "💡 Create it with: echo 'password=your-secure-dev-password' > $(DEV_OVERLAY)/.env"; \
		exit 1; \
	fi
	@echo "✅ Development .env file found"

apply-dev: check-prerequisites check-cluster check-dev-env ## Deploy Redis Sentinel to development
	@echo "🚀 Deploying Redis Sentinel to development environment..."
	@kubectl create namespace $(NAMESPACE_DEV) --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -k $(DEV_OVERLAY)
	@echo "⏳ Waiting for deployment to be ready..."
	@kubectl wait --for=condition=ready helmrelease redis-sentinel -n $(NAMESPACE_DEV) --timeout=600s
	@echo "✅ Redis Sentinel deployed to development"
	@make status-dev

teardown-dev: check-prerequisites check-cluster ## Remove Redis Sentinel from development
	@echo "🗑️  Tearing down Redis Sentinel development environment..."
	@kubectl delete -k $(DEV_OVERLAY) --ignore-not-found=true
	@echo "⏳ Waiting for resources to be removed..."
	@sleep 10
	@echo "🧹 Cleaning up namespace..."
	@kubectl delete namespace $(NAMESPACE_DEV) --ignore-not-found=true --timeout=120s
	@echo "✅ Development environment torn down"

# Production Environment
check-prod-env: ## Check if production .env file exists
	@if [ ! -f "$(PROD_OVERLAY)/.env" ]; then \
		echo "❌ Missing $(PROD_OVERLAY)/.env file"; \
		echo "💡 Create it with: echo 'password=your-secure-prod-password' > $(PROD_OVERLAY)/.env"; \
		exit 1; \
	fi
	@echo "✅ Production .env file found"

apply-prod: check-prerequisites check-cluster check-prod-env ## Deploy Redis Sentinel to production
	@echo "🚀 Deploying Redis Sentinel to production environment..."
	@kubectl create namespace $(NAMESPACE_PROD) --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -k $(PROD_OVERLAY)
	@echo "⏳ Waiting for deployment to be ready..."
	@kubectl wait --for=condition=ready helmrelease redis-sentinel -n $(NAMESPACE_PROD) --timeout=600s
	@echo "✅ Redis Sentinel deployed to production"
	@make status-prod

teardown-prod: check-prerequisites check-cluster ## Remove Redis Sentinel from production
	@echo "🗑️  Tearing down Redis Sentinel production environment..."
	@read -p "⚠️  This will delete production Redis data. Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ]
	@kubectl delete -k $(PROD_OVERLAY) --ignore-not-found=true
	@echo "⏳ Waiting for resources to be removed..."
	@sleep 10
	@echo "🧹 Cleaning up namespace..."
	@kubectl delete namespace $(NAMESPACE_PROD) --ignore-not-found=true --timeout=120s
	@echo "✅ Production environment torn down"

# Status and Monitoring
status: status-flux status-dev status-prod ## Show status of all environments

status-flux: check-cluster ## Show Flux controller status
	@echo "📊 Flux Controllers Status:"
	@kubectl get pods -n flux-system -o wide

status-dev: check-cluster ## Show development environment status
	@echo "📊 Development Environment Status:"
	@echo "Namespace: $(NAMESPACE_DEV)"
	@if kubectl get namespace $(NAMESPACE_DEV) >/dev/null 2>&1; then \
		echo "Flux Resources:"; \
		flux get all -n $(NAMESPACE_DEV) 2>/dev/null || echo "No Flux resources found"; \
		echo ""; \
		echo "Kubernetes Resources:"; \
		kubectl get all -n $(NAMESPACE_DEV) 2>/dev/null || echo "Namespace not found"; \
	else \
		echo "❌ Namespace $(NAMESPACE_DEV) does not exist"; \
	fi

status-prod: check-cluster ## Show production environment status  
	@echo "📊 Production Environment Status:"
	@echo "Namespace: $(NAMESPACE_PROD)"
	@if kubectl get namespace $(NAMESPACE_PROD) >/dev/null 2>&1; then \
		echo "Flux Resources:"; \
		flux get all -n $(NAMESPACE_PROD) 2>/dev/null || echo "No Flux resources found"; \
		echo ""; \
		echo "Kubernetes Resources:"; \
		kubectl get all -n $(NAMESPACE_PROD) 2>/dev/null || echo "Namespace not found"; \
	else \
		echo "❌ Namespace $(NAMESPACE_PROD) does not exist"; \
	fi

# Logs and Debugging
logs-dev: check-cluster ## Show Redis logs from development
	@echo "📋 Redis Development Logs:"
	@kubectl logs -n $(NAMESPACE_DEV) -l app.kubernetes.io/name=redis -c redis --tail=50

logs-sentinel-dev: check-cluster ## Show Sentinel logs from development
	@echo "📋 Sentinel Development Logs:"
	@kubectl logs -n $(NAMESPACE_DEV) -l app.kubernetes.io/name=redis -c sentinel --tail=50

logs-prod: check-cluster ## Show Redis logs from production
	@echo "📋 Redis Production Logs:"
	@kubectl logs -n $(NAMESPACE_PROD) -l app.kubernetes.io/name=redis -c redis --tail=50

logs-sentinel-prod: check-cluster ## Show Sentinel logs from production
	@echo "📋 Sentinel Production Logs:"  
	@kubectl logs -n $(NAMESPACE_PROD) -l app.kubernetes.io/name=redis -c sentinel --tail=50

logs-flux: check-cluster ## Show Flux controller logs
	@echo "📋 Flux Controller Logs:"
	@echo "Helm Controller:"
	@kubectl logs -n flux-system deployment/helm-controller --tail=20
	@echo ""
	@echo "Source Controller:"
	@kubectl logs -n flux-system deployment/source-controller --tail=20

# Testing and Validation
test-dev: check-cluster ## Test Redis connectivity in development
	@echo "🧪 Testing Redis development connectivity..."
	@POD=$$(kubectl get pods -n $(NAMESPACE_DEV) -l app.kubernetes.io/name=redis -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -n "$$POD" ]; then \
		echo "Testing Redis connection on pod: $$POD"; \
		PASSWORD=$$(kubectl get secret redis-sentinel-password -n $(NAMESPACE_DEV) -o jsonpath='{.data.password}' 2>/dev/null | base64 -d); \
		if [ -n "$$PASSWORD" ]; then \
			kubectl exec -n $(NAMESPACE_DEV) $$POD -c redis -- redis-cli -a "$$PASSWORD" ping 2>/dev/null || echo "❌ Redis connection failed"; \
		else \
			echo "❌ Could not retrieve Redis password"; \
		fi; \
	else \
		echo "❌ No Redis pods found in $(NAMESPACE_DEV)"; \
	fi

test-prod: check-cluster ## Test Redis connectivity in production
	@echo "🧪 Testing Redis production connectivity..."
	@POD=$$(kubectl get pods -n $(NAMESPACE_PROD) -l app.kubernetes.io/name=redis -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -n "$$POD" ]; then \
		echo "Testing Redis connection on pod: $$POD"; \
		PASSWORD=$$(kubectl get secret redis-sentinel-password -n $(NAMESPACE_PROD) -o jsonpath='{.data.password}' 2>/dev/null | base64 -d); \
		if [ -n "$$PASSWORD" ]; then \
			kubectl exec -n $(NAMESPACE_PROD) $$POD -c redis -- redis-cli -a "$$PASSWORD" ping 2>/dev/null || echo "❌ Redis connection failed"; \
		else \
			echo "❌ Could not retrieve Redis password"; \
		fi; \
	else \
		echo "❌ No Redis pods found in $(NAMESPACE_PROD)"; \
	fi

# Flux Operations
reconcile-dev: check-cluster ## Force reconcile development environment
	@echo "🔄 Force reconciling development environment..."
	@flux reconcile source helm redis-sentinel -n $(NAMESPACE_DEV)
	@flux reconcile helmrelease redis-sentinel -n $(NAMESPACE_DEV)

reconcile-prod: check-cluster ## Force reconcile production environment
	@echo "🔄 Force reconciling production environment..."
	@flux reconcile source helm redis-sentinel -n $(NAMESPACE_PROD)
	@flux reconcile helmrelease redis-sentinel -n $(NAMESPACE_PROD)

suspend-dev: check-cluster ## Suspend development environment reconciliation
	@echo "⏸️  Suspending development environment reconciliation..."
	@flux suspend helmrelease redis-sentinel -n $(NAMESPACE_DEV)

resume-dev: check-cluster ## Resume development environment reconciliation
	@echo "▶️  Resuming development environment reconciliation..."
	@flux resume helmrelease redis-sentinel -n $(NAMESPACE_DEV)

suspend-prod: check-cluster ## Suspend production environment reconciliation
	@echo "⏸️  Suspending production environment reconciliation..."
	@flux suspend helmrelease redis-sentinel -n $(NAMESPACE_PROD)

resume-prod: check-cluster ## Resume production environment reconciliation
	@echo "▶️  Resuming production environment reconciliation..."
	@flux resume helmrelease redis-sentinel -n $(NAMESPACE_PROD)

# Utility Commands
clean: ## Clean up all environments
	@echo "🧹 Cleaning up all Redis Sentinel environments..."
	@make teardown-dev teardown-prod

setup-dev-env: ## Create development .env file template
	@if [ ! -f "$(DEV_OVERLAY)/.env" ]; then \
		echo "password=super-secure-dev-redis-password-2024" > $(DEV_OVERLAY)/.env; \
		echo "✅ Created $(DEV_OVERLAY)/.env with default password"; \
		echo "💡 Edit the file to set your own password"; \
	else \
		echo "⚠️  $(DEV_OVERLAY)/.env already exists"; \
	fi

setup-prod-env: ## Create production .env file template  
	@if [ ! -f "$(PROD_OVERLAY)/.env" ]; then \
		echo "password=super-secure-prod-redis-password-2024" > $(PROD_OVERLAY)/.env; \
		echo "✅ Created $(PROD_OVERLAY)/.env with default password"; \
		echo "💡 Edit the file to set your own password"; \
	else \
		echo "⚠️  $(PROD_OVERLAY)/.env already exists"; \
	fi

port-forward-dev: check-cluster ## Port forward Redis development (localhost:6379)
	@echo "🔗 Port forwarding Redis development to localhost:6379..."
	@POD=$$(kubectl get pods -n $(NAMESPACE_DEV) -l app.kubernetes.io/name=redis -o jsonpath='{.items[0].metadata.name}'); \
	kubectl port-forward -n $(NAMESPACE_DEV) $$POD 6379:6379

port-forward-sentinel-dev: check-cluster ## Port forward Sentinel development (localhost:26379)
	@echo "🔗 Port forwarding Sentinel development to localhost:26379..."
	@POD=$$(kubectl get pods -n $(NAMESPACE_DEV) -l app.kubernetes.io/name=redis -o jsonpath='{.items[0].metadata.name}'); \
	kubectl port-forward -n $(NAMESPACE_DEV) $$POD 26379:26379

describe-dev: check-cluster ## Describe development HelmRelease for troubleshooting
	@echo "🔍 Describing development HelmRelease..."
	@kubectl describe helmrelease redis-sentinel -n $(NAMESPACE_DEV)

describe-prod: check-cluster ## Describe production HelmRelease for troubleshooting
	@echo "🔍 Describing production HelmRelease..."
	@kubectl describe helmrelease redis-sentinel -n $(NAMESPACE_PROD)

# Quick Start
quick-start: install-flux setup-dev-env apply-dev ## Quick start: Install Flux and deploy development environment
	@echo "🎉 Quick start complete! Redis Sentinel is running in development."
	@echo "💡 Run 'make test-dev' to verify the deployment" 