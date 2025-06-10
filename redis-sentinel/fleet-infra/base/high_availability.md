# Redis Sentinel High Availability Configuration

## Overview
This document explains the high availability (HA) configuration for our Redis Sentinel setup and why each component is crucial for maintaining a resilient Redis cluster.

## Architecture Components

### 1. Redis Master-Replica Setup
- **Master Node**: Single primary node handling write operations
- **Replica Nodes**: 3 replica nodes for read operations and failover
- **Why 3 Replicas?**
  - Provides redundancy for read operations
  - Ensures sufficient replicas for failover scenarios
  - Maintains quorum even if one replica fails
  - Improves read scalability

### 2. Redis Sentinel Configuration
- **Quorum**: Set to 2
  - Minimum number of sentinels that must agree on a failover
  - With 3 sentinels, quorum of 2 ensures majority agreement
  - Prevents split-brain scenarios
- **Down After Milliseconds**: 60000 (60 seconds)
  - Time before a sentinel considers a Redis instance down
  - Balances between quick failover and network glitch tolerance
- **Failover Timeout**: 180000 (3 minutes)
  - Maximum time for a failover to complete
  - Prevents stuck failover operations

## Pod Anti-Affinity Configuration

### Why Pod Anti-Affinity is Crucial
1. **Node Distribution**
   - Prevents single point of failure
   - Ensures Redis instances and Sentinels run on different nodes
   - Protects against node-level failures

2. **Resource Isolation**
   - Prevents resource contention between Redis instances
   - Ensures consistent performance
   - Better resource utilization across the cluster

3. **Network Isolation**
   - Reduces network congestion on individual nodes
   - Improves network performance for Redis operations
   - Better network fault isolation

### Configuration Details
```yaml
podAntiAffinity: "hard"
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app.kubernetes.io/name
          operator: In
          values:
          - redis
      topologyKey: "kubernetes.io/hostname"
```

- **Hard Requirements**: Uses `requiredDuringSchedulingIgnoredDuringExecution`
  - Ensures strict pod distribution
  - Pods won't schedule if requirements can't be met
  - Maximum availability guarantee

## Resource Requirements

### Minimum Cluster Requirements
- At least 4 nodes in the cluster
- Nodes should be in different availability zones if possible
- Each node should have:
  - Minimum 2Gi memory available
  - Minimum 500m CPU available
  - Sufficient storage for persistence (8Gi per instance)

### Resource Limits
```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "500m"
  limits:
    memory: "4Gi"
    cpu: "1000m"
```

## Best Practices for HA

1. **Node Distribution**
   - Spread Redis instances across different availability zones
   - Use node labels to control pod placement
   - Monitor node health and resource usage

2. **Monitoring**
   - Enable metrics collection
   - Monitor sentinel status
   - Track failover events
   - Monitor resource usage

3. **Backup and Recovery**
   - Regular backups of Redis data
   - Test recovery procedures
   - Document failover processes

4. **Network Considerations**
   - Ensure low latency between nodes
   - Configure appropriate network policies
   - Monitor network health

## Failure Scenarios and Recovery

1. **Node Failure**
   - Sentinels detect node failure
   - Automatic failover to healthy replica
   - New replica created on available node

2. **Network Partition**
   - Sentinels maintain quorum
   - Failover only if majority agrees
   - Prevents split-brain scenarios

3. **Resource Exhaustion**
   - Resource limits prevent node overload
   - Pod anti-affinity ensures resource availability
   - Monitoring alerts for resource issues

## Maintenance Considerations

1. **Updates and Upgrades**
   - Plan updates during low-traffic periods
   - Update replicas before master
   - Monitor sentinel status during updates

2. **Scaling**
   - Add replicas as needed
   - Ensure new nodes meet resource requirements
   - Update anti-affinity rules if needed

3. **Backup and Restore**
   - Regular backup schedule
   - Test restore procedures
   - Document recovery steps 