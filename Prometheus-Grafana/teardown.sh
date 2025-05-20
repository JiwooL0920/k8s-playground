#!/bin/bash

# Uninstall Grafana
echo "Uninstalling Grafana..."
helm uninstall grafana -n monitoring

# Uninstall Prometheus
echo "Uninstalling Prometheus..."
helm uninstall prometheus -n monitoring

# Delete the namespace (optional, remove the --wait flag if you want to delete immediately)
echo "Deleting namespace..."
kubectl delete namespace monitoring --wait=false

echo "Uninstallation complete." 