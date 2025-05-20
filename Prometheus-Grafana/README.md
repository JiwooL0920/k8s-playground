# Prometheus and Grafana on Kubernetes

This directory contains manifests and configuration files to deploy Prometheus and Grafana on a Kubernetes cluster using Helm charts.

## Prerequisites

- Kubernetes cluster (the setup includes a Kind cluster configuration)
- kubectl
- Helm v3

## Files

- `kind-config.yaml`: Configuration for the Kind cluster
- `namespace.yaml`: Kubernetes namespace manifest
- `prometheus-values.yaml`: Custom values for Prometheus Helm chart
- `grafana-values.yaml`: Custom values for Grafana Helm chart
- `deploy.sh`: Script to deploy Prometheus and Grafana
- `teardown.sh`: Script to uninstall Prometheus and Grafana

## Setup

1. Create a Kind cluster (if not using an existing cluster):
   ```
   kind create cluster --config kind-config.yaml
   ```

2. Run the deployment script:
   ```
   cd Prometheus-Grafana
   ./deploy.sh
   ```

3. Access the dashboards:
   - Prometheus: http://localhost:30090
   - Grafana: http://localhost:30080 (username: admin, password: admin)

## Cleanup

To remove Prometheus and Grafana:
```
cd Prometheus-Grafana
./teardown.sh
```

To delete the Kind cluster:
```
kind delete cluster --name prometheus-grafana
``` 