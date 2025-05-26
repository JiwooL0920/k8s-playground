# Elasticsearch with Flux HelmRelease

A production-ready Elasticsearch deployment using GitOps with Flux CD, featuring high availability, monitoring capabilities, and environment-specific configurations.

## 🚀 Quick Start

```bash
# Install Flux and deploy Elasticsearch to development
make quick-start

# Test the deployment
make test-dev

# Access Elasticsearch
make port-forward-dev
# Then visit: http://localhost:9200
```

## 🔧 Key Differences from Redis Sentinel

| Feature | Redis Sentinel | Elasticsearch |
|---------|----------------|---------------|
| **Primary Use** | In-memory caching & data structure store | Search & analytics engine |
| **Port** | 6379 (Redis), 26379 (Sentinel) | 9200 (HTTP), 9300 (Transport) |
| **Authentication** | Password-based in both dev & prod | Disabled in dev, X-Pack security in prod |
| **Clustering** | Master-Replica with Sentinel monitoring | Elasticsearch cluster with master quorum |
| **Storage** | Optional persistence | Persistent storage for indices |
| **Health Check** | `redis-cli ping` | `curl localhost:9200/_cluster/health` |

## 📊 Deployment Architecture

### Development Environment
- **Single node** Elasticsearch cluster
- **No authentication** for simplicity
- **Minimal resources** (512Mi memory)
- **5Gi storage** for development data
- **Port 9200** for HTTP API

### Production Environment  
- **3-node cluster** with high availability
- **X-Pack security** enabled with authentication
- **Production resources** (4Gi memory)
- **50Gi storage** per node
- **Anti-affinity** rules for node distribution

## 🔍 Available Commands

### Deployment
```bash
make apply-dev          # Deploy to development
make apply-prod         # Deploy to production (requires .env)
make teardown-dev       # Remove development
make teardown-prod      # Remove production
```

### Monitoring
```bash
make status-dev         # Show development status
make test-dev           # Test Elasticsearch health
make logs-dev           # View Elasticsearch logs
make port-forward-dev   # Access on localhost:9200
```

### Production Setup
```bash
make setup-prod-env     # Create production .env template
make apply-prod         # Deploy to production
make test-prod          # Test production deployment
```

## 🔐 Security Configuration

### Development
- **No authentication** required
- **Security disabled** for ease of development
- **HTTP-only** (no SSL/TLS)

### Production
- **Username**: `elastic`
- **Password**: Set in `.env` file
- **SSL/TLS** transport encryption
- **X-Pack security** features enabled

## 🌐 Accessing Elasticsearch

### Development
```bash
# Via port-forward
make port-forward-dev
curl http://localhost:9200/_cluster/health

# Via kubectl port-forward directly
kubectl port-forward -n elasticsearch-dev svc/elasticsearch-dev-elasticsearch 9200:9200
```

### Production
```bash
# Get the password
kubectl get secret elasticsearch-credentials -n elasticsearch-prod -o jsonpath='{.data.password}' | base64 -d

# Via port-forward with authentication
make port-forward-prod
curl -u elastic:YOUR_PASSWORD http://localhost:9200/_cluster/health
```

## 📚 Common Elasticsearch Operations

### Cluster Health
```bash
curl http://localhost:9200/_cluster/health?pretty
```

### Create Index
```bash
curl -X PUT http://localhost:9200/my-index
```

### Index Document
```bash
curl -X POST http://localhost:9200/my-index/_doc \
  -H 'Content-Type: application/json' \
  -d '{"name": "John Doe", "age": 30}'
```

### Search Documents
```bash
curl http://localhost:9200/my-index/_search?pretty
```

## 🔧 Troubleshooting

### Common Issues
```bash
# Check pod status
kubectl get pods -n elasticsearch-dev

# View detailed pod events
kubectl describe pod <pod-name> -n elasticsearch-dev

# Check Elasticsearch logs
make logs-dev

# Check Flux deployment status
flux get all -n elasticsearch-dev
```

### Performance Tuning
- **JVM Heap**: Configured via `esJavaOpts`
- **Memory**: Set appropriate resource limits
- **Storage**: Use high-performance storage classes
- **Network**: Ensure low-latency networking between nodes

## 🔄 Migration from Redis

If migrating from Redis to Elasticsearch:

1. **Data Migration**: Redis and Elasticsearch serve different purposes
2. **Application Changes**: Update client libraries and APIs
3. **Monitoring**: Different metrics and health checks
4. **Backup Strategy**: Elasticsearch snapshots vs Redis persistence

---

**Note**: This deployment uses the official Elastic Helm chart with Flux CD for GitOps-based management.