# Temporal with CloudNative PostgreSQL Manifests

This directory contains all the Kubernetes manifests needed to set up Temporal with CloudNative PostgreSQL.

## Directory Structure

```
manifests/
├── databases/         # Database definitions for Temporal
├── postgresql/        # PostgreSQL cluster configuration
└── secrets/           # Kubernetes secrets for authentication
```

## Resource Overview and Dependencies

### PostgreSQL Setup (Prerequisites)

1. **PostgreSQL Secrets**: `secrets/postgresql-secrets.yaml`
   - Creates the `cluster-superuser` secret with PostgreSQL admin credentials
   - Creates the `cluster-app-user` secret with application user credentials
   - **Used by**: PostgreSQL cluster for authentication

2. **PostgreSQL Cluster**: `postgresql/postgresql-cluster.yaml`
   - Defines a CloudNative PostgreSQL cluster with 3 replicas
   - References the secrets from `secrets/postgresql-secrets.yaml`
   - **Depends on**: CNPG operator must be installed in the cluster
   - **Used by**: Temporal databases, which are created within this PostgreSQL cluster

### Temporal Setup

1. **Temporal Database User**: `secrets/db-credentials-temporal.yaml`
   - Copies the database credentials to the Temporal namespace
   - **Used by**: Temporal services to connect to the PostgreSQL database

2. **Temporal Databases**: `databases/temporal-databases.yaml`
   - Creates the `temporal` and `temporal_visibility` databases
   - Creates them in the PostgreSQL cluster defined in `postgresql/postgresql-cluster.yaml`
   - **Depends on**: PostgreSQL cluster must be running
   - **Used by**: Temporal services for storing workflow and visibility data

### External Files

1. **Temporal Configuration**: `helm-charts/temporal/values.yaml` (not in this directory)
   - Configures Temporal services through Helm
   - References the database connection details and credentials
   - **Depends on**: All resources in this directory must be applied first

## Application Order

To properly deploy this stack, apply the manifests in the following order:

1. Create namespaces:
   ```bash
   kubectl create namespace cnpg-system --dry-run=client -o yaml | kubectl apply -f -
   kubectl create namespace temporal --dry-run=client -o yaml | kubectl apply -f -
   ```

2. Apply secrets:
   ```bash
   kubectl apply -f manifests/secrets/postgresql-secrets.yaml
   kubectl apply -f manifests/secrets/db-credentials-temporal.yaml
   ```

3. Create PostgreSQL cluster:
   ```bash
   kubectl apply -f manifests/postgresql/postgresql-cluster.yaml
   ```

4. Wait for PostgreSQL cluster to be ready:
   ```bash
   kubectl wait --for=condition=Ready cluster/postgresql-cluster -n cnpg-system --timeout=300s
   ```

5. Create Temporal databases:
   ```bash
   kubectl apply -f manifests/databases/temporal-databases.yaml
   ```

6. Deploy Temporal using Helm (referencing the values file):
   ```bash
   helm install temporal temporal \
     -f helm-charts/temporal/values.yaml \
     --namespace temporal
   ```

## Resource Details

### PostgreSQL Cluster (`postgresql-cluster.yaml`)
- Creates a stateful set with 3 PostgreSQL instances
- Sets up PostgreSQL with proper authentication
- Creates initial database `appdb` with owner `appuser`
- Configures monitoring

### Temporal Databases (`temporal-databases.yaml`)
- `temporal`: Main database for workflow execution data
- `temporal_visibility`: Database for workflow visibility data (search and listing)

### Secrets
- `cluster-superuser`: PostgreSQL admin credentials (username: postgres)
- `cluster-app-user` (in cnpg-system): Application user credentials (username: appuser)
- `cluster-app-user` (in temporal): Same credentials copied to Temporal namespace

## Connection Flow

1. **Databases**: CloudNative PG operator creates PostgreSQL databases in the `cnpg-system` namespace
2. **Credentials**: Stored in Kubernetes secrets in both namespaces
3. **Connection**: Temporal services connect to PostgreSQL using:
   - URL: `postgresql-cluster-rw.cnpg-system.svc.cluster.local:5432`
   - Credentials: From the `cluster-app-user` secret
   - Database names: `temporal` and `temporal_visibility` 