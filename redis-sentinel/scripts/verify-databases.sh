#!/bin/bash

# Redis Database Verification Script
# This script tests that all 6 databases are properly isolated

set -e

echo "🔍 Testing Redis Database Isolation..."

# Get Redis password from secret
REDIS_PASSWORD=$(kubectl get secret redis-sentinel-password -n redis-sentinel-prod -o jsonpath='{.data.password}' | base64 -d)

# Redis master pod
REDIS_POD=$(kubectl get pods -n redis-sentinel-prod -l app.kubernetes.io/component=master -o jsonpath='{.items[0].metadata.name}')

echo "📡 Using Redis pod: $REDIS_POD"

# Test data for each database
declare -A TEST_DATA=(
    [0]="thanos:query:cache"
    [2]="loki:results:cache"
    [3]="loki:chunk:cache"
    [4]="loki:write:dedupe"
    [5]="loki:index:cache"
    [6]="oneai:service:cache"
)

# Set test data in each database
echo "📝 Setting test data in each database..."
for db in "${!TEST_DATA[@]}"; do
    key="${TEST_DATA[$db]}"
    value="test-data-db-$db-$(date +%s)"
    
    echo "  Setting $key = $value in DB $db"
    kubectl exec -n redis-sentinel-prod $REDIS_POD -- \
        redis-cli -a "$REDIS_PASSWORD" -n "$db" \
        SET "$key" "$value" > /dev/null
done

# Verify database isolation
echo "🔎 Verifying database isolation..."
for db in "${!TEST_DATA[@]}"; do
    echo "  📊 Database $db contents:"
    
    # Get all keys in this database
    keys=$(kubectl exec -n redis-sentinel-prod $REDIS_POD -- \
        redis-cli -a "$REDIS_PASSWORD" -n "$db" KEYS "*" 2>/dev/null)
    
    if [ -z "$keys" ]; then
        echo "    ❌ No keys found in database $db"
    else
        echo "    ✅ Keys: $keys"
        
        # Get values for verification
        for key in $keys; do
            value=$(kubectl exec -n redis-sentinel-prod $REDIS_POD -- \
                redis-cli -a "$REDIS_PASSWORD" -n "$db" GET "$key" 2>/dev/null)
            echo "      $key = $value"
        done
    fi
    echo
done

# Test cross-database isolation
echo "🔒 Testing cross-database isolation..."
test_key="cross-db-test"

# Set the same key in databases 0 and 6 with different values
kubectl exec -n redis-sentinel-prod $REDIS_POD -- \
    redis-cli -a "$REDIS_PASSWORD" -n 0 SET "$test_key" "db0-value" > /dev/null

kubectl exec -n redis-sentinel-prod $REDIS_POD -- \
    redis-cli -a "$REDIS_PASSWORD" -n 6 SET "$test_key" "db6-value" > /dev/null

# Verify they're isolated
db0_value=$(kubectl exec -n redis-sentinel-prod $REDIS_POD -- \
    redis-cli -a "$REDIS_PASSWORD" -n 0 GET "$test_key" 2>/dev/null)

db6_value=$(kubectl exec -n redis-sentinel-prod $REDIS_POD -- \
    redis-cli -a "$REDIS_PASSWORD" -n 6 GET "$test_key" 2>/dev/null)

if [ "$db0_value" == "db0-value" ] && [ "$db6_value" == "db6-value" ]; then
    echo "✅ Database isolation working correctly!"
    echo "   DB 0: $test_key = $db0_value"
    echo "   DB 6: $test_key = $db6_value"
else
    echo "❌ Database isolation failed!"
    echo "   DB 0: $test_key = $db0_value (expected: db0-value)"
    echo "   DB 6: $test_key = $db6_value (expected: db6-value)"
    exit 1
fi

# Show database info
echo "📈 Redis Database Information:"
kubectl exec -n redis-sentinel-prod $REDIS_POD -- \
    redis-cli -a "$REDIS_PASSWORD" INFO keyspace

echo "🎉 Database verification complete!"
echo ""
echo "📋 Connection Information:"
echo "  Master (writes): redis-sentinel-master.redis-sentinel-prod.svc.cluster.local:6379"
echo "  Replicas (reads): redis-sentinel-replica.redis-sentinel-prod.svc.cluster.local:6379"
echo "  Sentinel: redis-sentinel.redis-sentinel-prod.svc.cluster.local:26379"
echo ""
echo "🔐 Use the redis-sentinel-password secret for authentication"
