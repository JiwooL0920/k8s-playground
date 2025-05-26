# Redis Sentinel with Flux HelmRelease

A production-ready Redis Sentinel deployment using GitOps with Flux CD, featuring high availability, monitoring capabilities, and environment-specific configurations.

## 📋 Table of Contents

- [Overview](#overview)
- [Repository Structure](#repository-structure)
- [HelmRelease Configuration](#helmrelease-configuration)
- [Deployed Resources](#deployed-resources)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Verification](#verification)
- [Environment Configurations](#environment-configurations)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

This repository implements Redis Sentinel using Flux CD's HelmRelease CRD with the Bitnami Redis Helm chart. It provides:

- **High Availability**: Redis Sentinel architecture with automatic failover
- **GitOps**: Flux CD for continuous deployment and drift detection
- **Multi-Environment**: Separate configurations for development and production
- **Security**: Encrypted password management via Kustomize secrets
- **Monitoring**: Optional Prometheus metrics and ServiceMonitor support
- **OCI Registry**: Uses OCI-compatible Helm repositories for modern chart distribution

## 📁 Repository Structure

```
Redis-Sentinel/fleet-infra/
├── .gitignore                              # Git ignore patterns
├── README.md                              # This documentation
├── base/                                  # Base Kustomize configuration
│   ├── helmrelease.yaml                   # HelmRepository + HelmRelease CRDs
│   └── kustomization.yaml                 # Base Kustomize manifest
└── overlays/                             # Environment-specific overlays
    ├── develop/                          # Development environment
    │   ├── .env                          # Development secrets (gitignored)
    │   ├── helmrelease-patch.yaml        # Development-specific overrides
    │   └── kustomization.yaml            # Development Kustomize manifest
    └── production/                       # Production environment  
        ├── .env                          # Production secrets (gitignored)
        ├── helmrelease-patch.yaml        # Production-specific overrides
        └── kustomization.yaml            # Production Kustomize manifest
```

### Key Files Explained

- **`base/helmrelease.yaml`**: Contains both HelmRepository and HelmRelease CRDs
- **`.env` files**: Store Redis passwords securely (gitignored)
- **`helmrelease-patch.yaml`**: Environment-specific Helm value overrides
- **`kustomization.yaml`**: Kustomize manifests with secret generation

## ⚙️ HelmRelease Configuration

### Base Configuration (`base/helmrelease.yaml`)

Our HelmRelease uses the Bitnami Redis chart with the following key customizations:

#### HelmRepository
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: redis-sentinel
spec:
  type: oci                                    # OCI registry type
  interval: 5m                                 # Check for updates every 5 minutes
  url: oci://registry-1.docker.io/bitnamicharts
```

#### HelmRelease Values
```yaml
values:
  architecture: replication                     # Enable Redis replication
  
  auth:
    enabled: true                              # Enable authentication
    existingSecret: "redis-sentinel-password"  # Use Kustomize-generated secret
    existingSecretPasswordKey: "password"      # Secret key name
    
  sentinel:
    enabled: true                              # Enable Sentinel
    masterSet: "mymaster"                      # Master set name
    quorum: 2                                  # Sentinel quorum
    downAfterMilliseconds: 60000               # Failure detection time
    failoverTimeout: 180000                    # Failover timeout
    parallelSyncs: 1                          # Parallel synchronization
    
  master:
    count: 1                                   # Single master
    persistence:
      enabled: true                            # Persistent storage
      size: 8Gi                               # Storage size
      
  replica:
    replicaCount: 2                           # Number of replicas
    persistence:
      enabled: true                            # Persistent storage
      size: 8Gi                               # Storage size
```

### Environment-Specific Overrides

#### Development (`overlays/develop/helmrelease-patch.yaml`)
- **Resource Optimization**: Lower CPU/memory limits for cost efficiency
- **No Persistence**: Faster startup with ephemeral storage
- **Single Replica**: Minimal setup for development
- **Lower Quorum**: Only 1 sentinel needed for quorum
- **Debug Logging**: Verbose logging for troubleshooting

#### Production (`overlays/production/helmrelease-patch.yaml`)
- **High Availability**: Multiple replicas with proper resource allocation
- **Persistent Storage**: Data persistence for production workloads
- **Monitoring**: Prometheus metrics and ServiceMonitor integration
- **Proper Quorum**: Multiple sentinels for consensus

## 🚀 Deployed Resources

When deployed, this configuration creates Kubernetes resources across multiple namespaces:

### Namespace Organization

| Namespace | Purpose | Resources |
|-----------|---------|-----------|
| `flux-system` | Flux Controllers | Flux source-controller, helm-controller |
| `redis-sentinel-dev` | Development Environment | Redis Sentinel cluster resources |
| `redis-sentinel-prod` | Production Environment | Redis Sentinel cluster resources |

### Flux System Namespace (`flux-system`)

```bash
# Flux Controllers (installed separately)
deployment.apps/source-controller   # Manages HelmRepositories
deployment.apps/helm-controller     # Manages HelmReleases

# Controller Services
service/source-controller
service/helm-controller

# Controller ConfigMaps and Secrets
configmap/source-controller-manager-config
secret/source-controller-manager-webhook-certs
```

### Development Environment (`redis-sentinel-dev` namespace)

```bash
# Redis Application Resources
pod/redis-sentinel-dev-redis-sentinel-node-0   2/2   Running
statefulset.apps/redis-sentinel-dev-redis-sentinel-node   1/1
service/redis-sentinel-dev-redis-sentinel            ClusterIP   6379/TCP,26379/TCP
service/redis-sentinel-dev-redis-sentinel-headless   ClusterIP   6379/TCP,26379/TCP

# Security Resources
secret/redis-sentinel-password   Opaque   1   # Generated by Kustomize

# Flux GitOps Resources
helmrelease.helm.toolkit.fluxcd.io/redis-sentinel     # Manages the Helm deployment
helmrepository.source.toolkit.fluxcd.io/redis-sentinel # OCI chart repository

# Storage Resources (if persistence enabled)
persistentvolumeclaim/redis-data-redis-sentinel-dev-redis-sentinel-node-0
```

### Production Environment (`redis-sentinel-prod` namespace)

```bash
# Redis Application Resources (when deployed)
pod/redis-sentinel-prod-redis-sentinel-node-0   2/2   Running
pod/redis-sentinel-prod-redis-sentinel-node-1   2/2   Running  # Additional replicas
statefulset.apps/redis-sentinel-prod-redis-sentinel-node   2/2
service/redis-sentinel-prod-redis-sentinel             ClusterIP   6379/TCP,26379/TCP
service/redis-sentinel-prod-redis-sentinel-headless    ClusterIP   6379/TCP,26379/TCP

# Monitoring Resources (production only)
service/redis-sentinel-prod-redis-sentinel-metrics     ClusterIP   9121/TCP
servicemonitor.monitoring.coreos.com/redis-sentinel-prod-redis-sentinel

# Security Resources
secret/redis-sentinel-password   Opaque   1   # Generated by Kustomize

# Flux GitOps Resources
helmrelease.helm.toolkit.fluxcd.io/redis-sentinel     # Manages the Helm deployment
helmrepository.source.toolkit.fluxcd.io/redis-sentinel # OCI chart repository

# Storage Resources
persistentvolumeclaim/redis-data-redis-sentinel-prod-redis-sentinel-node-0
persistentvolumeclaim/redis-data-redis-sentinel-prod-redis-sentinel-node-1
```

### Pod Container Details

Each Redis StatefulSet pod contains **two containers**:

| Container | Port | Purpose | Health Check |
|-----------|------|---------|--------------|
| `redis` | 6379 | Redis server | `redis-cli ping` |
| `sentinel` | 26379 | Redis Sentinel monitor | `redis-cli -p 26379 ping` |

### Service Details

| Service Type | Purpose | Ports | Scope |
|--------------|---------|-------|-------|
| `redis-sentinel` | Client connections | 6379 (Redis), 26379 (Sentinel) | ClusterIP |
| `redis-sentinel-headless` | StatefulSet discovery | 6379 (Redis), 26379 (Sentinel) | Headless |
| `redis-sentinel-metrics` | Prometheus monitoring | 9121 (Metrics) | Production only |

### Resource Verification Commands

```bash
# Check all resources in development namespace
kubectl get all,secrets,pvc,helmreleases,helmrepositories -n redis-sentinel-dev

# Check all resources in production namespace
kubectl get all,secrets,pvc,helmreleases,helmrepositories -n redis-sentinel-prod

# Check Flux controllers
kubectl get all -n flux-system

# Check resources across all namespaces
kubectl get helmreleases,helmrepositories -A
```

## 🔍 Complete Cluster Overview

### Expected Output: `kubectl get all --all-namespaces`

When you run `kubectl get all --all-namespaces` after deploying Redis Sentinel with Flux, you should see output similar to this:

```bash
NAMESPACE            NAME                                           READY   STATUS    RESTARTS   AGE
flux-system          pod/helm-controller-5d7b4d4f8c-xyz123         1/1     Running   0          1h
flux-system          pod/source-controller-6b9c8d7e5f-abc456       1/1     Running   0          1h
kube-system          pod/coredns-558bd4d5db-def789                 1/1     Running   0          2h
kube-system          pod/etcd-kind-control-plane                   1/1     Running   0          2h
kube-system          pod/kindnet-ghi012                            1/1     Running   0          2h
kube-system          pod/kube-apiserver-kind-control-plane         1/1     Running   0          2h
kube-system          pod/kube-controller-manager-kind-control-plane 1/1    Running   0          2h
kube-system          pod/kube-proxy-jkl345                         1/1     Running   0          2h
kube-system          pod/kube-scheduler-kind-control-plane         1/1     Running   0          2h
redis-sentinel-dev   pod/redis-sentinel-dev-redis-sentinel-node-0  2/2     Running   0          30m

NAMESPACE            NAME                                                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                  AGE
default              service/kubernetes                                  ClusterIP   10.96.0.1       <none>        443/TCP                  2h
flux-system          service/source-controller                           ClusterIP   10.96.123.45    <none>        80/TCP                   1h
flux-system          service/helm-controller                             ClusterIP   10.96.234.56    <none>        80/TCP                   1h
kube-system          service/kube-dns                                    ClusterIP   10.96.0.10      <none>        53/UDP,53/TCP,9153/TCP   2h
redis-sentinel-dev   service/redis-sentinel-dev-redis-sentinel          ClusterIP   10.96.218.211   <none>        6379/TCP,26379/TCP       30m
redis-sentinel-dev   service/redis-sentinel-dev-redis-sentinel-headless ClusterIP   None            <none>        6379/TCP,26379/TCP       30m

NAMESPACE            NAME                           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
kube-system          daemonset.apps/kindnet         1         1         1       1            1           <none>          2h
kube-system          daemonset.apps/kube-proxy      1         1         1       1            1           <none>          2h

NAMESPACE            NAME                                    READY   UP-TO-DATE   AVAILABLE   AGE
flux-system          deployment.apps/helm-controller        1/1     1            1           1h
flux-system          deployment.apps/source-controller      1/1     1            1           1h
kube-system          deployment.apps/coredns                1/1     1            1           2h

NAMESPACE            NAME                                               DESIRED   CURRENT   READY   AGE
flux-system          replicaset.apps/helm-controller-5d7b4d4f8c        1         1         1       1h
flux-system          replicaset.apps/source-controller-6b9c8d7e5f      1         1         1       1h
kube-system          replicaset.apps/coredns-558bd4d5db                1         1         1       2h

NAMESPACE            NAME                                                      READY   AGE
redis-sentinel-dev   statefulset.apps/redis-sentinel-dev-redis-sentinel-node  1/1     30m
```

### Resource Breakdown by Namespace

#### `default` Namespace
```bash
service/kubernetes                # Kubernetes API server service
```
- **Purpose**: Core Kubernetes API endpoint
- **Relevance**: System service, not related to our Redis deployment

#### `kube-system` Namespace
```bash
# Core Kubernetes Components
pod/coredns-*                     # DNS service for the cluster
pod/etcd-*                        # Kubernetes datastore
pod/kube-apiserver-*              # Kubernetes API server
pod/kube-controller-manager-*     # Kubernetes controller manager
pod/kube-scheduler-*              # Kubernetes scheduler
pod/kube-proxy-*                  # Network proxy on each node
pod/kindnet-*                     # CNI plugin (for kind clusters)

# Services
service/kube-dns                  # DNS service

# DaemonSets
daemonset.apps/kindnet            # Network plugin (one per node)
daemonset.apps/kube-proxy         # Proxy service (one per node)

# Deployments
deployment.apps/coredns           # DNS service deployment
```
- **Purpose**: Core Kubernetes system components
- **Relevance**: Required for cluster operation, not related to our Redis deployment

#### `flux-system` Namespace
```bash
# Flux Controller Pods
pod/helm-controller-*             # Manages HelmRelease resources
pod/source-controller-*           # Manages HelmRepository and other sources

# Flux Services
service/helm-controller           # Helm controller webhook service
service/source-controller         # Source controller webhook service

# Flux Deployments
deployment.apps/helm-controller   # Helm controller deployment
deployment.apps/source-controller # Source controller deployment

# Flux ReplicaSets
replicaset.apps/helm-controller-* # Managed by helm controller deployment
replicaset.apps/source-controller-* # Managed by source controller deployment
```
- **Purpose**: Flux CD GitOps controllers
- **Relevance**: **Critical for our Redis deployment** - these controllers manage our HelmRepository and HelmRelease resources

#### `redis-sentinel-dev` Namespace
```bash
# Redis Application Pod
pod/redis-sentinel-dev-redis-sentinel-node-0  # Our Redis Sentinel pod with 2 containers

# Redis Services
service/redis-sentinel-dev-redis-sentinel           # Main service for client connections
service/redis-sentinel-dev-redis-sentinel-headless  # Headless service for StatefulSet

# Redis StatefulSet
statefulset.apps/redis-sentinel-dev-redis-sentinel-node  # Manages Redis pods with persistent identity
```
- **Purpose**: Our Redis Sentinel application
- **Relevance**: **This is our main application** - Redis Sentinel with high availability

### What's Missing from `kubectl get all`

The `kubectl get all` command doesn't show everything. To see the complete picture, run these additional commands:

```bash
# Show secrets (including our Redis password)
kubectl get secrets --all-namespaces
# Expected: redis-sentinel-password in redis-sentinel-dev namespace

# Show Flux GitOps resources
kubectl get helmreleases,helmrepositories --all-namespaces
# Expected: HelmRelease and HelmRepository in redis-sentinel-dev namespace

# Show persistent volume claims (if persistence enabled)
kubectl get pvc --all-namespaces
# Expected: PVCs for Redis data storage

# Show config maps
kubectl get configmaps --all-namespaces
# Expected: Redis configuration and Flux controller configs
```

### Resource Count Summary

For a typical Redis Sentinel deployment, expect:

| Namespace | Pods | Services | Deployments | StatefulSets | Secrets | Other |
|-----------|------|----------|-------------|--------------|---------|-------|
| `kube-system` | 7+ | 1 | 1 | 0 | Multiple | DaemonSets, ConfigMaps |
| `flux-system` | 2 | 2 | 2 | 0 | Multiple | ReplicaSets, ConfigMaps |
| `redis-sentinel-dev` | 1 | 2 | 0 | 1 | 1+ | HelmRelease, HelmRepository |
| **Total** | **10+** | **5** | **3** | **1** | **Multiple** | **Various** |

## 📋 Prerequisites

- **Kubernetes Cluster**: v1.20+ (tested with kind/minikube)
- **kubectl**: v1.20+
- **Flux CLI**: v2.5.1+
- **Git**: For GitOps workflow

## 🔧 Installation

### 1. Install Flux CLI

```bash
# macOS
brew install fluxcd/tap/flux

# Linux
curl -s https://fluxcd.io/install.sh | sudo bash

# Verify installation
flux version
```

### 2. Install Flux Controllers

Install the required Flux controllers in your cluster:

```bash
# Install Flux controllers
flux install --components=source-controller,helm-controller

# Verify installation
kubectl get pods -n flux-system
```

Expected output:
```
NAME                                  READY   STATUS    RESTARTS   AGE
helm-controller-xxx                   1/1     Running   0          30s
source-controller-xxx                 1/1     Running   0          30s
```

### 3. Set Up Environment Secrets

Create `.env` files for your environments:

#### Development
```bash
cd overlays/develop
echo "password=your-secure-dev-password-2024" > .env
```

#### Production
```bash
cd overlays/production  
echo "password=your-secure-prod-password-2024" > .env
```

> ⚠️ **Security Note**: `.env` files are gitignored. Never commit passwords to version control.

### 4. Deploy to Development

```bash
# Deploy to development environment
kubectl apply -k overlays/develop

# Watch deployment progress
kubectl get pods -n redis-sentinel-dev -w
```

### 5. Deploy to Production (Optional)

```bash
# Create production namespace
kubectl create namespace redis-sentinel-prod

# Deploy to production environment
kubectl apply -k overlays/production

# Watch deployment progress  
kubectl get pods -n redis-sentinel-prod -w
```

## ✅ Verification

### 1. Check Flux Resources

```bash
# Check HelmRepository status
kubectl get helmrepositories -n redis-sentinel-dev
# Expected: READY=True, STATUS shows chart info

# Check HelmRelease status  
kubectl get helmreleases -n redis-sentinel-dev
# Expected: READY=True, STATUS shows successful install
```

### 2. Verify Pod Health

```bash
# Check pod status
kubectl get pods -n redis-sentinel-dev
# Expected: 2/2 Running

# Check pod logs
kubectl logs redis-sentinel-dev-redis-sentinel-node-0 -c redis -n redis-sentinel-dev
kubectl logs redis-sentinel-dev-redis-sentinel-node-0 -c sentinel -n redis-sentinel-dev
```

### 3. Test Redis Connectivity

```bash
# Get the password from your .env file
PASSWORD=$(cat overlays/develop/.env | cut -d'=' -f2)

# Test Redis connection
kubectl exec -it redis-sentinel-dev-redis-sentinel-node-0 -n redis-sentinel-dev -c redis -- \
  redis-cli -a "$PASSWORD" ping
# Expected: PONG

# Test Redis operations
kubectl exec -it redis-sentinel-dev-redis-sentinel-node-0 -n redis-sentinel-dev -c redis -- \
  redis-cli -a "$PASSWORD" set test-key "Hello World"
# Expected: OK

kubectl exec -it redis-sentinel-dev-redis-sentinel-node-0 -n redis-sentinel-dev -c redis -- \
  redis-cli -a "$PASSWORD" get test-key  
# Expected: "Hello World"
```

### 4. Test Sentinel Functionality

```bash
# Check Sentinel status
kubectl exec -it redis-sentinel-dev-redis-sentinel-node-0 -n redis-sentinel-dev -c sentinel -- \
  redis-cli -p 26379 -a "$PASSWORD" sentinel masters
# Expected: Shows master information

# Alternative: Check Sentinel status with direct password
kubectl exec -it redis-sentinel-dev-redis-sentinel-node-0 -n redis-sentinel-dev -c sentinel -- \
  redis-cli -p 26379 -a super-secure-dev-redis-password-2024 sentinel masters
# Expected: Shows master information

# Check monitored instances
kubectl exec -it redis-sentinel-dev-redis-sentinel-node-0 -n redis-sentinel-dev -c sentinel -- \
  redis-cli -p 26379 -a "$PASSWORD" sentinel sentinels redis-dev
# Expected: Shows sentinel information
```

### 5. Test Secret Access

```bash
# Verify secret exists
kubectl get secret redis-sentinel-password -n redis-sentinel-dev
# Expected: Shows secret with correct age

# Check secret contents (base64 encoded)
kubectl get secret redis-sentinel-password -n redis-sentinel-dev -o yaml
# Expected: Shows password key with base64 encoded value

# Decode secret to verify
kubectl get secret redis-sentinel-password -n redis-sentinel-dev -o jsonpath='{.data.password}' | base64 -d
# Expected: Shows your actual password
```

## 🌍 Environment Configurations

### Development Environment
- **Namespace**: `redis-sentinel-dev`
- **Resources**: Minimal (64Mi memory, 50m CPU)
- **Persistence**: Disabled for faster startup
- **Replicas**: 1 replica node
- **Quorum**: 1 (single sentinel quorum)
- **Logging**: Verbose for debugging

### Production Environment  
- **Namespace**: `redis-sentinel-prod`
- **Resources**: Production-grade (1Gi memory, 500m CPU)
- **Persistence**: Enabled with 20Gi storage
- **Replicas**: 2 replica nodes
- **Quorum**: 2 (proper sentinel consensus)
- **Monitoring**: Full Prometheus integration

## 📊 Monitoring

The production environment includes comprehensive monitoring:

### Metrics Collection
- **Redis Exporter**: Bitnami redis-exporter (port 9121)
- **Sentinel Metrics**: Built-in Sentinel monitoring
- **ServiceMonitor**: Prometheus Operator integration

### Monitoring Configuration
```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
    labels:
      prometheus: kube-prometheus-stack
```

### Accessing Metrics
```bash
# Port-forward to metrics endpoint
kubectl port-forward service/redis-sentinel-prod-redis-sentinel-metrics 9121:9121 -n redis-sentinel-prod

# View metrics
curl http://localhost:9121/metrics
```

## 🔍 Troubleshooting

### Common Issues

#### 1. HelmRelease Not Ready
```bash
# Check HelmRelease events
kubectl describe helmrelease redis-sentinel -n redis-sentinel-dev

# Check Flux controller logs
kubectl logs -n flux-system deployment/helm-controller
kubectl logs -n flux-system deployment/source-controller
```

#### 2. Pod CrashLoopBackOff
```bash
# Check pod events
kubectl describe pod <pod-name> -n redis-sentinel-dev

# Check container logs
kubectl logs <pod-name> -c redis -n redis-sentinel-dev --previous
kubectl logs <pod-name> -c sentinel -n redis-sentinel-dev --previous
```

#### 3. Secret Mount Issues
```bash
# Verify secret exists
kubectl get secrets -n redis-sentinel-dev

# Check secret format
kubectl get secret redis-sentinel-password -n redis-sentinel-dev -o yaml

# Ensure correct key name (should be "password")
```

#### 4. Authentication Failures
```bash
# Verify password in secret matches .env file
kubectl get secret redis-sentinel-password -n redis-sentinel-dev -o jsonpath='{.data.password}' | base64 -d

# Test without authentication (if auth issues)
kubectl exec -it <pod-name> -n redis-sentinel-dev -c redis -- redis-cli ping
```

### Useful Commands

```bash
# Restart HelmRelease (force reconciliation)
kubectl annotate helmrelease redis-sentinel -n redis-sentinel-dev \
  reconcile.fluxcd.io/requestedAt="$(date +%s)"

# Force Flux to check for updates
flux reconcile source helm redis-sentinel -n redis-sentinel-dev
flux reconcile helmrelease redis-sentinel -n redis-sentinel-dev

# View Helm release history
helm history redis-sentinel-dev-redis-sentinel -n redis-sentinel-dev

# Clean slate (delete everything)
kubectl delete -k overlays/develop
```

## 📚 Additional Resources

- [Flux Documentation](https://fluxcd.io/docs/)
- [Bitnami Redis Chart](https://github.com/bitnami/charts/tree/main/bitnami/redis)
- [Redis Sentinel Documentation](https://redis.io/docs/management/sentinel/)
- [Kustomize Documentation](https://kustomize.io/)

## 🔒 Security Considerations

- **Secrets Management**: All passwords are stored in gitignored `.env` files
- **Network Policies**: Consider implementing NetworkPolicies for production
- **RBAC**: Ensure proper RBAC for Flux controllers
- **TLS**: Consider enabling TLS for Redis connections in production
- **Password Rotation**: Implement regular password rotation procedures

## 🧪 Additional Verification Steps

Here are some additional commands you can use to thoroughly test your Redis Sentinel deployment:

### Quick Redis Test
```bash
# Quick ping test
kubectl exec -it redis-sentinel-dev-redis-sentinel-node-0 -n redis-sentinel-dev -c redis -- \
  redis-cli -a super-secure-dev-redis-password-2024 ping
# Expected: PONG
```

### Detailed Sentinel Information
```bash
# Get comprehensive sentinel masters information
kubectl exec -it redis-sentinel-dev-redis-sentinel-node-0 -n redis-sentinel-dev -c sentinel -- \
  redis-cli -p 26379 -a super-secure-dev-redis-password-2024 sentinel masters
# Expected: Detailed master configuration and status

# Get sentinel configuration
kubectl exec -it redis-sentinel-dev-redis-sentinel-node-0 -n redis-sentinel-dev -c sentinel -- \
  redis-cli -p 26379 -a super-secure-dev-redis-password-2024 info sentinel
# Expected: Sentinel runtime information

# Check all known sentinels
kubectl exec -it redis-sentinel-dev-redis-sentinel-node-0 -n redis-sentinel-dev -c sentinel -- \
  redis-cli -p 26379 -a super-secure-dev-redis-password-2024 sentinel sentinels redis-dev
# Expected: List of all sentinels monitoring the master
```

### Redis Database Operations
```bash
# Set multiple test keys
kubectl exec -it redis-sentinel-dev-redis-sentinel-node-0 -n redis-sentinel-dev -c redis -- \
  redis-cli -a super-secure-dev-redis-password-2024 mset \
  user:1:name "Alice" user:1:email "alice@example.com" user:1:active "true"
# Expected: OK

# Get all test keys
kubectl exec -it redis-sentinel-dev-redis-sentinel-node-0 -n redis-sentinel-dev -c redis -- \
  redis-cli -a super-secure-dev-redis-password-2024 mget \
  user:1:name user:1:email user:1:active
# Expected: Array of values

# Check database info
kubectl exec -it redis-sentinel-dev-redis-sentinel-node-0 -n redis-sentinel-dev -c redis -- \
  redis-cli -a super-secure-dev-redis-password-2024 info replication
# Expected: Replication status and details
```

### Resource Monitoring
```bash
# Check resource usage
kubectl top pods -n redis-sentinel-dev
# Expected: CPU and memory usage for Redis pods

# Monitor pod events
kubectl get events -n redis-sentinel-dev --sort-by='.lastTimestamp'
# Expected: Recent events for the namespace

# Check persistent volumes (if enabled)
kubectl get pv,pvc -n redis-sentinel-dev
# Expected: Persistent volume claims and volumes
```

---

**Maintained by**: Your Team  
**Last Updated**: $(date +"%Y-%m-%d")  
**Flux Version**: v2.5.1  
**Chart Version**: redis-21.1.7 