#!/bin/bash

# Create namespace
kubectl apply -f namespace.yaml

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
echo "Installing Prometheus..."
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  -f prometheus-values.yaml

# Install Grafana
echo "Installing Grafana..."
helm install grafana grafana/grafana \
  --namespace monitoring \
  -f grafana-values.yaml

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=300s

# Display access information
echo ""
echo "===================================================================="
echo "Prometheus can be accessed at http://localhost:30090"
echo "Grafana can be accessed at http://localhost:30080"
echo "Grafana credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo "====================================================================" 