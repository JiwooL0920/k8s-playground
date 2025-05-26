# Redis Database Allocation Guide

## Database Assignments

| Database | Service | Purpose | Example Connection |
|----------|---------|---------|-------------------|
| DB 0 | Thanos Query Frontend | Query result caching | `redis://redis-sentinel:6379/0` |
| DB 2 | Loki | Results cache | `redis://redis-sentinel:6379/2` |
| DB 3 | Loki | Chunk cache | `redis://redis-sentinel:6379/3` |
| DB 4 | Loki | Write dedupe cache | `redis://redis-sentinel:6379/4` |
| DB 5 | Loki | Index cache | `redis://redis-sentinel:6379/5` |
| DB 6 | OneAI | Microservices cache | `redis://redis-sentinel:6379/6` |

## Connection Examples

### Environment Variables
```bash
# Thanos
export REDIS_URL="redis://:${REDIS_PASSWORD}@redis-sentinel-master:6379/0"

# Loki Results Cache
export LOKI_RESULTS_CACHE_REDIS_URL="redis://:${REDIS_PASSWORD}@redis-sentinel-master:6379/2"

# Loki Chunk Cache
export LOKI_CHUNK_CACHE_REDIS_URL="redis://:${REDIS_PASSWORD}@redis-sentinel-master:6379/3"

# Loki Write Dedupe Cache
export LOKI_WRITE_DEDUPE_REDIS_URL="redis://:${REDIS_PASSWORD}@redis-sentinel-master:6379/4"

# Loki Index Cache
export LOKI_INDEX_CACHE_REDIS_URL="redis://:${REDIS_PASSWORD}@redis-sentinel-master:6379/5"

# OneAI
export ONEAI_REDIS_URL="redis://:${REDIS_PASSWORD}@redis-sentinel-master:6379/6"
```

### High Availability with Sentinel
```bash
# Use sentinel for automatic failover
REDIS_SENTINEL_URL="redis-sentinel://redis-sentinel:26379/0?master=mymaster"
```

## Application Configuration Examples

### Python (using redis-py)
```python
import redis

# Direct connection to specific database
r = redis.Redis(
    host='redis-sentinel-master',
    port=6379,
    db=0,  # Database number
    password='your-password'
)

# With Sentinel for HA
from redis.sentinel import Sentinel
sentinel = Sentinel([('redis-sentinel', 26379)])
master = sentinel.master_for('mymaster', socket_timeout=0.1, db=0)
```

### Go (using go-redis)
```go
import "github.com/go-redis/redis/v8"

// Direct connection
rdb := redis.NewClient(&redis.Options{
    Addr:     "redis-sentinel-master:6379",
    Password: "your-password",
    DB:       0, // Database number
})

// With Sentinel
rdb := redis.NewFailoverClient(&redis.FailoverOptions{
    MasterName:    "mymaster",
    SentinelAddrs: []string{"redis-sentinel:26379"},
    DB:            0,
})
```

### Node.js (using ioredis)
```javascript
const Redis = require('ioredis');

// Direct connection
const redis = new Redis({
  host: 'redis-sentinel-master',
  port: 6379,
  password: 'your-password',
  db: 0 // Database number
});

// With Sentinel
const redis = new Redis({
  sentinels: [{ host: 'redis-sentinel', port: 26379 }],
  name: 'mymaster',
  db: 0
});
```

## Testing Database Separation

### Using Redis CLI
```bash
# Connect to specific database
kubectl exec -it redis-sentinel-master-0 -- redis-cli -a your-password -n 0

# Set test data in different databases
redis-cli -a your-password -n 0 set "thanos:test" "db0-data"
redis-cli -a your-password -n 2 set "loki:test" "db2-data"
redis-cli -a your-password -n 6 set "oneai:test" "db6-data"

# Verify isolation
redis-cli -a your-password -n 0 keys "*"  # Should only show thanos data
redis-cli -a your-password -n 2 keys "*"  # Should only show loki data
```

## Service Discovery

Your applications should connect using these service names:
- **Master (writes)**: `redis-sentinel-master.redis-sentinel-prod.svc.cluster.local:6379`
- **Replicas (reads)**: `redis-sentinel-replica.redis-sentinel-prod.svc.cluster.local:6379`
- **Sentinel**: `redis-sentinel.redis-sentinel-prod.svc.cluster.local:26379`

## Security Notes

1. All databases share the same authentication
2. Database isolation is logical, not physical
3. Use network policies for additional security
4. Monitor per-database usage with Redis metrics
