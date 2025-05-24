# Kustomize Multi-Environment Nginx Deployment with Traefik

This project demonstrates how to use **Kustomize** to manage Kubernetes deployments across multiple environments (dev, uat) with **Traefik** as the ingress controller, showcasing infrastructure-as-code best practices.

## Table of Contents
- [Overview](#overview)
- [Why This Architecture](#why-this-architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
- [Testing](#testing)
- [Teardown](#teardown)
- [Understanding the Components](#understanding-the-components)
- [Common Commands](#common-commands)

## Overview

This project creates a simple nginx web server that can be deployed to multiple environments using Kustomize overlays. Each environment has its own configuration while sharing a common base, demonstrating:

- **Kustomize** for environment-specific configuration management
- **Traefik** as a modern ingress controller
- **IngressRoute** (Traefik CRD) for advanced routing capabilities
- **Kind** cluster for local development

## Why This Architecture

### Why Kustomize?
- **No templating complexity**: Works with plain YAML files
- **Environment consistency**: Same base configuration across all environments
- **Patch-based customization**: Only specify what changes between environments
- **Native Kubernetes**: Built into kubectl, no additional tools required
- **GitOps friendly**: Clear file structure for version control

### Why Traefik over NGINX Ingress Controller?
- **Modern architecture**: Cloud-native design with automatic service discovery
- **Rich CRDs**: IngressRoute provides more flexibility than standard Ingress
- **Better observability**: Built-in dashboard and metrics
- **WebSocket support**: Native support for modern web applications
- **Let's Encrypt integration**: Automatic SSL certificate management
- **Middleware system**: Extensible request/response processing

### Why Port Forwarding?
When using **Kind** (Kubernetes in Docker), services aren't directly accessible from your host machine. Port forwarding creates a tunnel from your local machine to the Kubernetes service, allowing you to test ingress controllers as if they were running on a real cluster.

## Project Structure

```
Kustomize/
├── base/                              # Base configuration (environment-agnostic)
│   ├── kustomization.yaml            # Base Kustomize configuration
│   ├── nginx-deployment.yaml         # Nginx deployment definition
│   ├── nginx-service.yaml            # Kubernetes service for Nginx
│   └── nginx-ingress-route.yaml      # Traefik IngressRoute configuration
├── overlays/                         # Environment-specific customizations
│   ├── dev/                          # Development environment
│   │   ├── kustomization.yaml        # Dev overlay configuration
│   │   ├── patch-deployment.yaml     # Dev-specific deployment patches
│   │   └── patch-ingressroute.yaml   # Dev-specific ingress patches
│   └── uat/                          # User Acceptance Testing environment
│       ├── kustomization.yaml        # UAT overlay configuration
│       ├── patch-deployment.yaml     # UAT-specific deployment patches
│       └── patch-ingressroute.yaml   # UAT-specific ingress patches
├── traefik-values.yaml               # Helm values for Traefik installation
├── Makefile                          # Automation scripts
└── README.md                         # This file
```

## Prerequisites

- **Docker Desktop** or **Docker** installed and running
- **Kind** cluster running
- **kubectl** configured to connect to your Kind cluster
- **Helm** installed (for Traefik installation)
- **sudo** access (for editing /etc/hosts)

### Verify Prerequisites
```bash
# Check Kind cluster
kubectl cluster-info

# Check Helm
helm version

# Check Docker
docker --version
```

## Setup Instructions

### 1. Install Traefik Ingress Controller

Traefik needs to be installed once per cluster:

```bash
# Create Traefik namespace
kubectl create namespace traefik

# Add Traefik Helm repository
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Install Traefik with custom values
helm install traefik traefik/traefik --namespace traefik --values traefik-values.yaml
```

### 2. Verify Traefik Installation

```bash
# Check Traefik pods
kubectl get pods -n traefik

# Check Traefik service (should show NodePort)
kubectl get svc -n traefik
```

### 3. Deploy Development Environment

```bash
# Apply dev configuration
kubectl apply -k overlays/dev

# Verify dev deployment
kubectl get pods,svc,ingressroute
```

### 4. Deploy UAT Environment

```bash
# Apply UAT configuration
kubectl apply -k overlays/uat

# Verify both environments
kubectl get pods,svc,ingressroute
```

### 5. Setup Port Forwarding

Since we're using Kind, we need to forward traffic from localhost to Traefik:

```bash
# Forward port 8080 on localhost to port 80 on Traefik service
kubectl port-forward -n traefik svc/traefik 8080:80
```

**Keep this terminal open** - the port forward runs in the foreground.

### 6. Add Hostnames to /etc/hosts

For local testing, we need to map our custom hostnames to localhost:

```bash
# Add dev hostname
echo "127.0.0.1 dev-nginx.localhost" | sudo tee -a /etc/hosts

# Add UAT hostname  
echo "127.0.0.1 uat-nginx.example.com" | sudo tee -a /etc/hosts
```

## Testing

With everything set up, you can now test both environments:

### Development Environment
- **URL**: http://dev-nginx.localhost:8080
- **Replicas**: 1 (resource-limited)
- **Resources**: 128Mi memory, 100m CPU

### UAT Environment  
- **URL**: http://uat-nginx.example.com:8080
- **Replicas**: 3 (production-like)
- **Resources**: 256Mi memory, 200m CPU

### Verification Commands

```bash
# Check all running pods
kubectl get pods

# Check service endpoints
kubectl get endpoints

# Check IngressRoute status
kubectl get ingressroute

# View Traefik dashboard (if enabled)
kubectl port-forward -n traefik svc/traefik 9000:9000
# Then visit: http://localhost:9000/dashboard/
```

## Teardown

### Remove Deployments

```bash
# Remove dev environment
kubectl delete -k overlays/dev

# Remove UAT environment  
kubectl delete -k overlays/uat

# Remove Traefik (optional)
helm uninstall traefik -n traefik
kubectl delete namespace traefik
```

### Clean up /etc/hosts

```bash
# Remove added hostnames (run individually)
sudo sed -i '' '/dev-nginx.localhost/d' /etc/hosts
sudo sed -i '' '/uat-nginx.example.com/d' /etc/hosts
```

## Understanding the Components

### Base Configuration Files

#### `base/nginx-deployment.yaml`
- Defines the core Nginx deployment
- Uses `nginx:alpine` image for smaller footprint
- Sets basic resource requirements
- **Environment-agnostic**: No environment-specific values

#### `base/nginx-service.yaml`
- Creates a ClusterIP service to expose Nginx pods
- Routes traffic from IngressRoute to Nginx pods
- Uses label selectors to find appropriate pods

#### `base/nginx-ingress-route.yaml`
- Traefik-specific CRD for advanced routing
- Defines hostname and routing rules
- **Why IngressRoute vs Ingress**: More flexible than standard Kubernetes Ingress
- Supports Traefik middleware, circuit breakers, and advanced routing

#### `base/kustomization.yaml`
- Lists all resources to include in the base
- Defines common labels applied to all resources
- **Deprecated warnings**: Kustomize recommends newer syntax

### Overlay Configuration Files

#### Overlay `kustomization.yaml` Files
- **`namePrefix`**: Adds environment prefix to all resource names
- **`commonLabels`**: Adds environment-specific labels
- **`patchesStrategicMerge`**: Lists patch files to apply

#### Deployment Patches
- **Dev**: Single replica, minimal resources (dev efficiency)
- **UAT**: Multiple replicas, higher resources (production-like testing)

#### IngressRoute Patches
- **Critical for Kustomize**: Fixes service name references after namePrefix
- **Dev**: Uses `dev-nginx.localhost` hostname
- **UAT**: Uses `uat-nginx.example.com` hostname

### Why Separate Patch Files?

Instead of hardcoding environment-specific values in the base:
- **Maintainability**: Easy to see what differs between environments
- **Reusability**: Base can be shared across teams/projects
- **Auditability**: Clear change tracking in version control
- **Scalability**: Easy to add new environments

## Common Commands

### Kustomize Operations
```bash
# Preview what will be applied (without applying)
kubectl kustomize overlays/dev
kubectl kustomize overlays/uat

# Apply specific environment
kubectl apply -k overlays/dev
kubectl apply -k overlays/uat

# Delete specific environment
kubectl delete -k overlays/dev
kubectl delete -k overlays/uat
```

### Debugging
```bash
# Check pod logs
kubectl logs -l app=nginx

# Describe problematic resources
kubectl describe ingressroute dev-nginx-test

# Check Traefik logs
kubectl logs -n traefik deployment/traefik

# Test service connectivity directly
kubectl port-forward svc/dev-nginx 8081:80
```

### Traefik Management
```bash
# Check Traefik status
kubectl get pods -n traefik

# Access Traefik dashboard
kubectl port-forward -n traefik svc/traefik 9000:9000

# View Traefik configuration
kubectl get ingressroute -o yaml
```

## Troubleshooting

### Common Issues

1. **404 Not Found**: Check IngressRoute service name matches actual service name
2. **Connection Refused**: Ensure port-forward is running
3. **DNS Resolution**: Verify /etc/hosts entries
4. **Resource Conflicts**: Check for duplicate names across environments

### Validation Steps

1. **Kustomize build**: `kubectl kustomize overlays/dev` should show valid YAML
2. **Resource creation**: All pods should be `Running`
3. **Service endpoints**: `kubectl get endpoints` should show pod IPs
4. **Ingress routing**: Traefik logs should show successful route registration

This architecture provides a robust foundation for managing Kubernetes applications across multiple environments while maintaining consistency and enabling environment-specific customizations.
