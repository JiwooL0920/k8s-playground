# AWS Secrets Manager Setup Guide

This guide walks you through setting up External Secrets Operator (ESO) with AWS Secrets Manager for your Elasticsearch deployment.

## 🔐 Prerequisites

1. **AWS Account** with Secrets Manager access
2. **EKS Cluster** (recommended) or self-managed cluster with AWS credentials
3. **IAM Permissions** to read from Secrets Manager

## 📋 Step 1: Create Secrets in AWS Secrets Manager

### Development Environment
```bash
# Create development Redis secret
aws secretsmanager create-secret \
  --name "redis/dev/credentials" \
  --description "Redis development environment password" \
  --secret-string '{"password":"dev-redis-password-123"}'

# Create development Elasticsearch secret  
aws secretsmanager create-secret \
  --name "elasticsearch/dev/credentials" \
  --description "Elasticsearch development environment credentials" \
  --secret-string '{"username":"elastic","password":"dev-elastic-password-123"}'
```

### Production Environment
```bash
# Create production Redis secret
aws secretsmanager create-secret \
  --name "redis/prod/credentials" \
  --description "Redis production environment password" \
  --secret-string '{"password":"SUPER-SECURE-REDIS-PASSWORD-2024"}'

# Create production Elasticsearch secret
aws secretsmanager create-secret \
  --name "elasticsearch/prod/credentials" \
  --description "Elasticsearch production environment credentials" \
  --secret-string '{"username":"elastic","password":"SUPER-SECURE-ELASTIC-PASSWORD-2024"}'
```

## 🔑 Step 2: Setup IAM Role (for EKS with IRSA)

### Create IAM Policy
```bash
cat > external-secrets-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": [
                "arn:aws:secretsmanager:REGION:ACCOUNT-ID:secret:redis/*",
                "arn:aws:secretsmanager:REGION:ACCOUNT-ID:secret:elasticsearch/*"
            ]
        }
    ]
}
EOF

# Create the policy
aws iam create-policy \
  --policy-name ExternalSecretsPolicy \
  --policy-document file://external-secrets-policy.json
```

### Create IAM Role for Service Account (IRSA)
```bash
# Replace with your values
CLUSTER_NAME="your-eks-cluster"
AWS_ACCOUNT_ID="123456789012"
AWS_REGION="us-west-2"

# Create IAM role
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=elasticsearch-dev \
  --name=external-secrets-sa \
  --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/ExternalSecretsPolicy \
  --override-existing-serviceaccounts \
  --approve

# Also create for production namespace
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=elasticsearch-prod \
  --name=external-secrets-sa \
  --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/ExternalSecretsPolicy \
  --override-existing-serviceaccounts \
  --approve
```

## 🔧 Step 3: Update Configuration Files

### Update SecretStore with your AWS details
Edit `fleet-infra/base/secretstore.yaml`:
```yaml
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2  # Your AWS region
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
```

### Update ExternalSecret references
Ensure the secret names in `externalsecret.yaml` match your AWS secrets:
- `redis/dev/credentials` 
- `redis/prod/credentials`
- `elasticsearch/dev/credentials`
- `elasticsearch/prod/credentials`

## 🚀 Step 4: Deploy with External Secrets

```bash
# Install External Secrets Operator
make install-external-secrets

# Deploy to development
make apply-dev

# Check secrets status  
make check-secrets

# Force refresh if needed
make force-sync-secrets
```

## 🔍 Step 5: Verification

### Check External Secrets Status
```bash
# Check ExternalSecret resources
kubectl get externalsecrets -A

# Check created secrets
kubectl get secrets -n elasticsearch-dev
kubectl get secrets -n elasticsearch-prod

# Describe ExternalSecret for troubleshooting
kubectl describe externalsecret redis-password-external -n elasticsearch-dev
```

### Test Secret Values
```bash
# Get the secret value (should match AWS)
kubectl get secret redis-sentinel-password -n elasticsearch-dev -o jsonpath='{.data.password}' | base64 -d

# Test Elasticsearch
make test-dev
```

## ⚠️ Troubleshooting

### Common Issues

#### 1. ExternalSecret Not Ready
```bash
# Check ExternalSecret status
kubectl describe externalsecret redis-password-external -n elasticsearch-dev

# Common issues:
# - IAM permissions
# - SecretStore configuration
# - Secret not found in AWS
```

#### 2. IAM Permission Errors
```bash
# Check ESO controller logs
kubectl logs -n external-secrets-system deployment/external-secrets -f

# Verify IAM role
kubectl describe serviceaccount external-secrets-sa -n elasticsearch-dev
```

#### 3. Secret Not Found in AWS
```bash
# List secrets in AWS
aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `redis`) || contains(Name, `elasticsearch`)]'

# Get secret value
aws secretsmanager get-secret-value --secret-id redis/dev/credentials
```

## 🔄 Secret Rotation

External Secrets automatically refreshes secrets based on the `refreshInterval`:
- Development: 60 minutes
- Production: 15 minutes

To force immediate refresh:
```bash
make force-sync-secrets
```

## 🛡️ Security Best Practices

1. **Least Privilege**: Only grant access to specific secret paths
2. **Audit Logging**: Enable CloudTrail for Secrets Manager
3. **Secret Rotation**: Use AWS automatic rotation
4. **Network Security**: Use VPC endpoints for Secrets Manager
5. **Monitoring**: Monitor External Secrets metrics

---

**Note**: Replace all placeholder values (ACCOUNT-ID, REGION, etc.) with your actual AWS values. 