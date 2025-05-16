#!/bin/bash
set -e

# Colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== N8N with SQLite Setup Script ===${NC}"

# Setup variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
NAMESPACE="n8n"
CHART_DIR="$BASE_DIR/helm-charts/n8n-helm-chart/charts/n8n"
VALUES_FILE="$BASE_DIR/helm-charts/n8n-values.yaml"
PV_FILE="$BASE_DIR/helm-charts/pv.yaml"
KIND_CONFIG="$BASE_DIR/kind-config.yaml"
RELEASE_NAME="n8n"

# Function to display steps
function step() {
    echo -e "${GREEN}==>${NC} $1"
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed.${NC}"
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm is not installed.${NC}"
    exit 1
fi

# Check if kind is installed
if ! command -v kind &> /dev/null; then
    echo -e "${RED}Error: kind is not installed.${NC}"
    exit 1
fi

# Create kind cluster if it doesn't exist
step "Checking for existing kind cluster 'n8n-cluster'..."
if ! kind get clusters | grep -q "n8n-cluster"; then
    step "Creating kind cluster with configuration at $KIND_CONFIG..."
    kind create cluster --config="$KIND_CONFIG"
else
    echo "Kind cluster 'n8n-cluster' already exists. Using existing cluster."
fi

# Create namespace if it doesn't exist
step "Creating namespace ${NAMESPACE} if it doesn't exist..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Apply persistent volumes
step "Creating persistent volume..."
kubectl apply -f "${PV_FILE}"

# Build Helm dependencies
step "Building Helm dependencies..."
cd "$BASE_DIR/helm-charts/n8n-helm-chart" && helm dependency build ./charts/n8n

# Check if n8n is already installed
if helm status ${RELEASE_NAME} -n ${NAMESPACE} &> /dev/null; then
    echo -e "${YELLOW}n8n is already installed. Upgrading...${NC}"
    helm upgrade ${RELEASE_NAME} ${CHART_DIR} -n ${NAMESPACE} -f ${VALUES_FILE}
else
    # Install n8n
    step "Installing n8n with Helm..."
    helm install ${RELEASE_NAME} ${CHART_DIR} -n ${NAMESPACE} -f ${VALUES_FILE}
fi

# Wait for pods to be ready
step "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod --selector=app.kubernetes.io/instance=${RELEASE_NAME} -n ${NAMESPACE} --timeout=300s

# Get the URL to access n8n
step "Getting the n8n URL..."
NODE_PORT=$(kubectl get --namespace ${NAMESPACE} -o jsonpath="{.spec.ports[0].nodePort}" services ${RELEASE_NAME})
echo -e "n8n should be accessible at: ${GREEN}http://localhost:5678${NC} (using port-forward)"
echo -e "Or via NodePort: ${GREEN}http://localhost:${NODE_PORT}${NC}"

# Start port-forwarding in the background
step "Setting up port-forwarding to access n8n..."
echo "Press Ctrl+C when you want to stop port-forwarding."
kubectl port-forward svc/${RELEASE_NAME} 5678:5678 -n ${NAMESPACE}

echo -e "${GREEN}Setup complete!${NC}"
echo "You can check the status of your pods with: kubectl get pods -n ${NAMESPACE}"
echo "To follow the logs: kubectl logs -f deployment/${RELEASE_NAME} -n ${NAMESPACE}"
echo "To uninstall n8n: helm uninstall ${RELEASE_NAME} -n ${NAMESPACE}" 