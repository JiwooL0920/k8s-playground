#!/bin/bash

# Exit on error
set -e

# Define image name and tag
IMAGE_NAME="fastapi-temporal"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
KIND_CLUSTER_NAME="cnpg-cluster"  # Use the correct cluster name

# Build the Docker image
echo "Building Docker image..."
docker build -t ${FULL_IMAGE_NAME} .

# Load the image into kind cluster
echo "Loading image into kind cluster..."
kind load docker-image ${FULL_IMAGE_NAME} --name ${KIND_CLUSTER_NAME}

# Apply Kubernetes manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f ../manifests/app/fastapi-deployment.yaml
kubectl apply -f ../manifests/app/fastapi-service.yaml

echo "Deployment completed!"
echo "To access the API, run: kubectl port-forward -n temporal svc/fastapi-temporal 8000:8000"
echo "Then visit: http://localhost:8000/docs to use the API" 