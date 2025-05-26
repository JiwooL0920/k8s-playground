# Service Connection Examples

## Thanos Query Frontend Configuration

### Environment Variables
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: thanos-query-config
data:
  THANOS_QUERY_FRONTEND_REDIS_URL: "redis://:$(REDIS_PASSWORD)@redis-sentinel-master:6379/0"
  THANOS_QUERY_FRONTEND_REDIS_DB: "0"
```

### Thanos Query Frontend Config
```yaml
query-frontend:
  response_cache_config:
    redis:
      addr: "redis-sentinel-master:6379"
      db: 0
      password: "$(REDIS_PASSWORD)"
      master_name: "mymaster"
```

## Loki Configuration

### Loki Config YAML
```yaml
query_range:
  results_cache:
    cache:
      redis:
        endpoint: "redis-sentinel-master:6379"
        db: 2
        password: "$(REDIS_PASSWORD)"

chunk_store_config:
  chunk_cache_config:
    redis:
      endpoint: "redis-sentinel-master:6379" 
      db: 3
      password: "$(REDIS_PASSWORD)"

ingester:
  chunk_cache_config:
    redis:
      endpoint: "redis-sentinel-master:6379"
      db: 4
      password: "$(REDIS_PASSWORD)"

storage_config:
  index_queries_cache_config:
    redis:
      endpoint: "redis-sentinel-master:6379"
      db: 5
      password: "$(REDIS_PASSWORD)"
```

## OneAI Service Configuration

### Environment Variables
```bash
export REDIS_HOST="redis-sentinel-master"
export REDIS_PORT="6379"
export REDIS_DB="6"
export REDIS_PASSWORD="$(kubectl get secret redis-sentinel-password -o jsonpath='{.data.password}' | base64 -d)"
```

### Python Configuration
```python
import redis
import os

redis_client = redis.Redis(
    host=os.getenv('REDIS_HOST', 'redis-sentinel-master'),
    port=int(os.getenv('REDIS_PORT', 6379)),
    db=int(os.getenv('REDIS_DB', 6)),
    password=os.getenv('REDIS_PASSWORD'),
    decode_responses=True
)
```

### Node.js Configuration
```javascript
const Redis = require('ioredis');

const redis = new Redis({
  host: process.env.REDIS_HOST || 'redis-sentinel-master',
  port: process.env.REDIS_PORT || 6379,
  db: process.env.REDIS_DB || 6,
  password: process.env.REDIS_PASSWORD,
  retryDelayOnFailover: 100,
  enableOfflineQueue: false,
  maxRetriesPerRequest: 3,
});
```

## High Availability with Sentinel

### Python with Sentinel
```python
from redis.sentinel import Sentinel

sentinel = Sentinel([
    ('redis-sentinel', 26379)
])

# Get master for writes (specific database)
master = sentinel.master_for('mymaster', socket_timeout=0.1, db=6)

# Get slave for reads (specific database)  
slave = sentinel.slave_for('mymaster', socket_timeout=0.1, db=6)
```

### Go with Sentinel
```go
import "github.com/go-redis/redis/v8"

rdb := redis.NewFailoverClient(&redis.FailoverOptions{
    MasterName:    "mymaster",
    SentinelAddrs: []string{"redis-sentinel:26379"},
    Password:      os.Getenv("REDIS_PASSWORD"),
    DB:            6, // OneAI database
})
```

## Connection Testing

### Test Each Database
```bash
# Test Thanos DB (0)
kubectl exec -it redis-sentinel-master-0 -n redis-sentinel-prod -- \
  redis-cli -a $REDIS_PASSWORD -n 0 ping

# Test Loki Results Cache (2)
kubectl exec -it redis-sentinel-master-0 -n redis-sentinel-prod -- \
  redis-cli -a $REDIS_PASSWORD -n 2 ping

# Test OneAI DB (6)
kubectl exec -it redis-sentinel-master-0 -n redis-sentinel-prod -- \
  redis-cli -a $REDIS_PASSWORD -n 6 ping
```

### Monitor Database Usage
```bash
# Show keyspace info for all databases
kubectl exec -it redis-sentinel-master-0 -n redis-sentinel-prod -- \
  redis-cli -a $REDIS_PASSWORD info keyspace

# Monitor commands on specific database
kubectl exec -it redis-sentinel-master-0 -n redis-sentinel-prod -- \
  redis-cli -a $REDIS_PASSWORD monitor | grep 'select 6'
```
