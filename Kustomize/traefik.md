# Traefik Ingress Controller Guide

## Table of Contents
- [What is Traefik?](#what-is-traefik)
- [Why Do We Need an Ingress Controller?](#why-do-we-need-an-ingress-controller)
- [Why Traefik Over Other Ingress Controllers?](#why-traefik-over-other-ingress-controllers)
- [Traefik vs Standard Kubernetes Ingress](#traefik-vs-standard-kubernetes-ingress)
- [IngressRoute Explained](#ingressroute-explained)
- [Our Traefik Setup](#our-traefik-setup)
- [Configuration Files Explained](#configuration-files-explained)
- [Installation Steps](#installation-steps)
- [Verification and Testing](#verification-and-testing)
- [Common Operations](#common-operations)
- [Troubleshooting](#troubleshooting)

## What is Traefik?

**Traefik** (pronounced "traffic") is a modern, cloud-native **reverse proxy and load balancer** that makes deploying microservices easy. It's specifically designed for containerized environments like Docker and Kubernetes.

### Key Characteristics:
- **Cloud-Native**: Built from the ground up for containerized environments
- **Dynamic Configuration**: Automatically discovers services and configures routing
- **Zero-Configuration**: Works out of the box with sensible defaults
- **Multi-Protocol Support**: HTTP, HTTPS, TCP, UDP, gRPC
- **Observability**: Built-in metrics, tracing, and dashboard
- **Edge Router**: Acts as the entry point for your cluster

### Architecture Overview:
```
Internet → Traefik (Edge Router) → Kubernetes Services → Pods
```

Traefik sits at the edge of your cluster and routes incoming requests to the appropriate backend services based on rules you define.

## Why Do We Need an Ingress Controller?

### The Problem Without Ingress:

In Kubernetes, by default:
- **Services** are only accessible within the cluster
- **NodePort** services expose random ports (30000-32767 range)
- **LoadBalancer** services require cloud provider support
- No hostname-based routing
- No SSL termination
- No single entry point

### Example Without Ingress:
```bash
# Without ingress, you'd need to:
kubectl port-forward svc/nginx-service 8080:80  # Manual port forwarding
# Or use NodePort with random ports like :31234
```

### The Solution With Ingress:

An **Ingress Controller** provides:
- **Single Entry Point**: One IP/port for all services
- **Hostname-based Routing**: `dev.example.com` → dev service, `prod.example.com` → prod service
- **Path-based Routing**: `/api/` → API service, `/web/` → web service
- **SSL Termination**: Handles HTTPS certificates
- **Load Balancing**: Distributes traffic across multiple pods
- **Traffic Management**: Rate limiting, authentication, etc.

## Why Traefik Over Other Ingress Controllers?

### Comparison with Popular Alternatives:

| Feature | Traefik | NGINX Ingress | HAProxy | AWS ALB |
|---------|---------|---------------|---------|---------|
| **Cloud-Native** | ✅ Built for containers | ⚠️ Traditional web server adapted | ⚠️ Traditional load balancer | ✅ Cloud-native |
| **Auto-Discovery** | ✅ Automatic | ❌ Manual configuration | ❌ Manual configuration | ✅ Automatic |
| **Configuration** | ✅ CRDs + Labels | ⚠️ Annotations + ConfigMaps | ❌ Config files | ✅ Annotations |
| **Dashboard** | ✅ Built-in web UI | ❌ Separate tools needed | ❌ Separate tools needed | ✅ AWS Console |
| **Learning Curve** | ✅ Easy | ⚠️ Moderate | ❌ Steep | ⚠️ AWS-specific |
| **Metrics** | ✅ Prometheus built-in | ⚠️ Requires setup | ⚠️ Requires setup | ✅ CloudWatch |

### Traefik's Advantages:

1. **Simplicity**: Zero-configuration approach with sensible defaults
2. **Developer Experience**: Intuitive configuration and excellent documentation
3. **Modern Architecture**: Designed for microservices and cloud environments
4. **Rich CRDs**: IngressRoute, Middleware, TLSOption for advanced features
5. **Observability**: Built-in dashboard, metrics, and tracing
6. **Active Community**: Frequent updates and community support

## Traefik vs Standard Kubernetes Ingress

### Standard Kubernetes Ingress Limitations:

```yaml
# Standard Ingress - Limited functionality
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    # Controller-specific annotations (not portable)
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

**Problems with Standard Ingress:**
- Limited to HTTP/HTTPS
- Heavy reliance on annotations (controller-specific)
- No native support for TCP/UDP
- Limited traffic management capabilities
- No middleware chaining

### Traefik IngressRoute Advantages:

```yaml
# IngressRoute - Rich functionality
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: example-route
spec:
  entryPoints:
    - web
    - websecure
  routes:
  - match: Host(`example.com`) && Path(`/api`)
    kind: Rule
    services:
    - name: api-service
      port: 80
    middlewares:
    - name: auth-middleware
    - name: rate-limit
  - match: Host(`example.com`) && Path(`/web`)
    kind: Rule
    services:
    - name: web-service
      port: 80
  tls:
    certResolver: letsencrypt
```

**IngressRoute Benefits:**
- **Explicit Configuration**: No hidden annotations
- **Rich Matching**: Complex routing rules with logical operators
- **Middleware Support**: Authentication, rate limiting, circuit breakers
- **Protocol Support**: HTTP, HTTPS, TCP, UDP
- **Advanced TLS**: Multiple certificates, SNI support

## IngressRoute Explained

### What is IngressRoute?

**IngressRoute** is Traefik's **Custom Resource Definition (CRD)** that extends Kubernetes with advanced routing capabilities. It's Traefik's alternative to the standard Kubernetes Ingress resource.

### Key Components:

#### 1. **EntryPoints**
Define which ports Traefik listens on:
```yaml
entryPoints:
  - web      # HTTP (port 80)
  - websecure # HTTPS (port 443)
```

#### 2. **Routes**
Define routing rules and target services:
```yaml
routes:
- match: Host(`example.com`) && Path(`/api`)
  kind: Rule
  services:
  - name: api-service
    port: 80
```

#### 3. **Match Expressions**
Powerful routing logic:
```yaml
# Host-based routing
match: Host(`api.example.com`)

# Path-based routing
match: Path(`/api`)

# Combined rules
match: Host(`example.com`) && Path(`/api`) && Method(`GET`)

# Header-based routing
match: Host(`example.com`) && Headers(`X-Version`, `v2`)
```

#### 4. **Middlewares**
Request/response processing pipeline:
```yaml
middlewares:
- name: auth          # Authentication
- name: rate-limit    # Rate limiting
- name: strip-prefix  # Path manipulation
- name: cors          # CORS headers
```

#### 5. **TLS Configuration**
SSL/TLS certificate management:
```yaml
tls:
  secretName: example-tls
  # Or automatic certificate generation
  certResolver: letsencrypt
```

### Our IngressRoute Configuration:

In our project, the base IngressRoute is simple:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: nginx-test
spec:
  entryPoints:
  - web        # HTTP only for local development
  - websecure  # HTTPS ready for production
  routes:
  - kind: Rule
    match: Host(`test-nginx.localhost`)  # Hostname matching
    services:
    - name: nginx     # Target service
      port: 80        # Service port
```

The overlays patch this with environment-specific hostnames:
- **Dev**: `dev-nginx.localhost`
- **UAT**: `uat-nginx.example.com`

## Our Traefik Setup

### Architecture in Our Project:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   localhost     │    │    Traefik      │    │  Nginx Pods     │
│    :8080        │───▶│  (traefik ns)   │───▶│  (nginx ns)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │  IngressRoute   │
                       │   Routing       │
                       │     Rules       │
                       └─────────────────┘
```

### Component Breakdown:

1. **Traefik Pod**: Runs in `traefik` namespace
2. **Traefik Service**: NodePort service exposing ports 80/443
3. **IngressRoute CRDs**: Define routing rules in `nginx` namespace
4. **Port Forward**: Tunnels localhost:8080 to Traefik service
5. **Nginx Services**: Backend services in `nginx` namespace

## Configuration Files Explained

### `/Kustomize/traefik-values.yaml`

This Helm values file customizes the Traefik installation:

```yaml
dashboard:
  enabled: true                    # Enable web dashboard
logs:
  general:
    level: INFO                    # Log level (DEBUG for troubleshooting)
  access:
    enabled: true                  # Enable access logs
    format: json                   # JSON format for better parsing
    fields:
      headers:
        defaultmode: keep          # Log all headers (useful for debugging)
service:
  type: NodePort                   # NodePort for Kind cluster compatibility
```

#### Why Each Setting:

**`dashboard.enabled: true`**
- Provides a web UI at `http://localhost:9000/dashboard/`
- Shows real-time routing configuration
- Useful for debugging and monitoring

**`logs.general.level: INFO`**
- Balances verbosity with usefulness
- Change to `DEBUG` for troubleshooting
- Avoid `DEBUG` in production (performance impact)

**`logs.access.enabled: true`**
- Logs all HTTP requests
- Useful for debugging routing issues
- Shows which rules are being matched

**`logs.access.format: json`**
- Structured logging for better parsing
- Easier integration with log aggregation tools
- Better than plain text for automation

**`service.type: NodePort`**
- **Kind Compatibility**: Kind doesn't support LoadBalancer services
- **Local Development**: Easy to port-forward
- **Alternative**: In cloud environments, use `LoadBalancer`

### Why Not LoadBalancer?

In cloud environments, you might use:
```yaml
service:
  type: LoadBalancer  # Gets external IP from cloud provider
  # annotations:
  #   service.beta.kubernetes.io/aws-load-balancer-type: nlb
```

But for Kind (local development):
- LoadBalancer services remain in "Pending" state
- No external IP is assigned
- NodePort is the practical choice

## Installation Steps

### Step-by-Step Installation Process:

#### 1. **Create Traefik Namespace**
```bash
kubectl create namespace traefik
```
**Why separate namespace?**
- Isolates infrastructure components
- Easier RBAC and resource management
- Cleaner organization

#### 2. **Add Traefik Helm Repository**
```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
```
**Why Helm?**
- Official packaging method
- Handles complex Kubernetes manifests
- Easy upgrades and rollbacks
- Community-maintained charts

#### 3. **Install with Custom Values**
```bash
helm install traefik traefik/traefik \
  --namespace traefik \
  --values traefik-values.yaml \
  --wait
```

**Command breakdown:**
- `helm install traefik`: Install with release name "traefik"
- `traefik/traefik`: Use chart from traefik repository
- `--namespace traefik`: Install in traefik namespace
- `--values traefik-values.yaml`: Use our custom configuration
- `--wait`: Wait for pods to be ready before completing

#### 4. **Verify Installation**
```bash
kubectl get pods -n traefik
kubectl get svc -n traefik
```

Expected output:
```
NAME                       READY   STATUS    RESTARTS   AGE
traefik-748f548468-kf5pr   1/1     Running   0          1m

NAME      TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
traefik   NodePort   10.96.192.138   <none>        80:32376/TCP,443:31606/TCP   1m
```

### Automated Installation (Makefile):

We've automated this in our Makefile:
```bash
make setup-traefik
```

This runs:
1. Creates namespace
2. Adds Helm repo
3. Installs Traefik
4. Verifies installation

## Verification and Testing

### 1. **Check Traefik Status**
```bash
# Verify Traefik is running
kubectl get pods -n traefik

# Check service endpoints
kubectl get svc -n traefik

# View Traefik logs
kubectl logs -n traefik deployment/traefik
```

### 2. **Access Traefik Dashboard**
```bash
# Port forward to dashboard
kubectl port-forward -n traefik svc/traefik 9000:9000

# Visit: http://localhost:9000/dashboard/
```

**Dashboard shows:**
- Active routes and rules
- Services and endpoints
- Middleware configuration
- Real-time metrics

### 3. **Test Routing**
```bash
# Setup port forwarding for HTTP traffic
kubectl port-forward -n traefik svc/traefik 8080:80

# Test dev environment
curl -H "Host: dev-nginx.localhost" http://localhost:8080

# Test UAT environment
curl -H "Host: uat-nginx.example.com" http://localhost:8080
```

### 4. **View IngressRoute Status**
```bash
# Check IngressRoute resources
kubectl get ingressroute -n nginx

# Detailed information
kubectl describe ingressroute dev-nginx-test -n nginx
```

## Common Operations

### **Upgrading Traefik**
```bash
# Update Helm repository
helm repo update

# Upgrade Traefik (preserves configuration)
helm upgrade traefik traefik/traefik \
  --namespace traefik \
  --values traefik-values.yaml
```

### **Viewing Traefik Configuration**
```bash
# Check what Traefik sees
kubectl get ingressroute,middleware,tlsoption -A

# View Traefik's generated configuration
kubectl logs -n traefik deployment/traefik | grep -i "configuration"
```

### **Backup Configuration**
```bash
# Export IngressRoute configurations
kubectl get ingressroute -n nginx -o yaml > ingressroutes-backup.yaml

# Export Traefik Helm values
helm get values traefik -n traefik > traefik-current-values.yaml
```

### **Performance Monitoring**
```bash
# View Traefik metrics (if enabled)
kubectl port-forward -n traefik svc/traefik 8080:8080
# Visit: http://localhost:8080/metrics

# Monitor resource usage
kubectl top pods -n traefik
```

## Troubleshooting

### **Common Issues and Solutions:**

#### 1. **404 Not Found**
**Symptoms**: Browser shows 404 when accessing application
**Causes**:
- IngressRoute not matching hostname
- Service name mismatch
- Wrong namespace

**Debug steps**:
```bash
# Check IngressRoute configuration
kubectl describe ingressroute -n nginx

# Verify service exists
kubectl get svc -n nginx

# Check Traefik logs
kubectl logs -n traefik deployment/traefik | tail -50

# Test with curl
curl -v -H "Host: dev-nginx.localhost" http://localhost:8080
```

#### 2. **Connection Refused**
**Symptoms**: "Connection refused" or timeout errors
**Causes**:
- Port forwarding not running
- Traefik not healthy
- Firewall issues

**Debug steps**:
```bash
# Check if port forward is running
ps aux | grep "port-forward"

# Verify Traefik pod status
kubectl get pods -n traefik

# Check Traefik service
kubectl get svc -n traefik

# Test direct connection to Traefik
kubectl port-forward -n traefik svc/traefik 8080:80 &
curl http://localhost:8080
```

#### 3. **SSL/TLS Issues**
**Symptoms**: Certificate errors or HTTPS not working
**Causes**:
- Missing TLS configuration
- Certificate not found
- Wrong entryPoint

**Debug steps**:
```bash
# Check TLS configuration
kubectl get secret -n nginx | grep tls

# Verify entryPoints in IngressRoute
kubectl get ingressroute -n nginx -o yaml

# Check Traefik TLS configuration
kubectl logs -n traefik deployment/traefik | grep -i tls
```

#### 4. **Service Discovery Issues**
**Symptoms**: Traefik can't find backend services
**Causes**:
- Service in wrong namespace
- Label selector mismatch
- Service port incorrect

**Debug steps**:
```bash
# Check service endpoints
kubectl get endpoints -n nginx

# Verify service labels
kubectl get svc -n nginx --show-labels

# Check if pods are running
kubectl get pods -n nginx

# Test service connectivity
kubectl port-forward -n nginx svc/dev-nginx 8081:80
curl http://localhost:8081
```

### **Useful Debug Commands:**

```bash
# Get all Traefik-related resources
kubectl get all -n traefik

# Detailed pod information
kubectl describe pods -n traefik

# Real-time logs
kubectl logs -n traefik deployment/traefik -f

# Check resource consumption
kubectl top pods -n traefik

# Validate YAML configuration
kubectl apply --dry-run=client -f ingressroute.yaml
```

### **Enable Debug Logging:**

Temporarily enable debug logging by updating traefik-values.yaml:
```yaml
logs:
  general:
    level: DEBUG  # Temporary - change back to INFO
```

Then upgrade:
```bash
helm upgrade traefik traefik/traefik \
  --namespace traefik \
  --values traefik-values.yaml
```

**Remember to change back to INFO level in production!**

This comprehensive guide should give you everything you need to understand and work with Traefik in our Kustomize setup. 