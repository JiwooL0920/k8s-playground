#!/bin/bash
set -e

# Colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== N8N Cleanup Script ===${NC}"

# Setup variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
NAMESPACE="n8n"
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

# Ask for confirmation
read -p "This will uninstall n8n and delete all related resources. Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Uninstall n8n Helm release if it exists
step "Uninstalling n8n Helm release..."
if helm status ${RELEASE_NAME} -n ${NAMESPACE} &> /dev/null; then
    helm uninstall ${RELEASE_NAME} -n ${NAMESPACE}
    echo "n8n Helm release uninstalled."
else
    echo "n8n Helm release not found. Skipping uninstall."
fi

# Delete PVCs
step "Deleting Persistent Volume Claims..."
kubectl delete pvc --all -n ${NAMESPACE} || true

# Delete PVs
step "Deleting Persistent Volume..."
kubectl delete pv n8n-data-pv || true

# Delete namespace
step "Deleting namespace ${NAMESPACE}..."
kubectl delete namespace ${NAMESPACE} || true

# Ask if the user wants to delete the kind cluster
read -p "Do you want to delete the kind cluster 'n8n-cluster'? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    step "Deleting kind cluster 'n8n-cluster'..."
    kind delete cluster --name n8n-cluster
    echo "Kind cluster deleted."
else
    echo "Kind cluster 'n8n-cluster' preserved."
fi

echo -e "${GREEN}Cleanup complete!${NC}" 