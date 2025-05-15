# Setting Up Temporal with CloudNative PostgreSQL

This guide explains how to set up Temporal workflow engine using CloudNative PostgreSQL (CNPG) as its backend storage.

## Resource Overview

```
Kubernetes Cluster
│
├── Namespace: cnpg-system
│   ├── CloudNative PostgreSQL Operator
│   │   └── Manages and orchestrates PostgreSQL resources
│   │
│   ├── PostgreSQL Cluster: postgresql-cluster
│   │   ├── StatefulSet: postgresql-cluster-{1,2,3} (PostgreSQL pods)
│   │   ├── Services:
│   │   │   ├── postgresql-cluster-rw (read-write endpoint) ◄──────────┐
│   │   │   ├── postgresql-cluster-ro (read-only endpoint)             │
│   │   │   └── postgresql-cluster-r (replica endpoint)                │
│   │   │                                                              │
│   │   └── Storage: PersistentVolumeClaims                            │
│   │                                                                  │
│   ├── Databases (CNPG Custom Resources):                             │
│   │   ├── temporal (main workflow data)                              │
│   │   └── temporal_visibility (workflow visibility data)             │
│   │       [Defined in: manifests/databases/temporal-databases.yaml]  │
│   │                                                                  │
│   └── Secret: cluster-app-user (DB credentials) ◄────────────┐       │
│       [Defined in: manifests/secrets/db-credentials.yaml]    │       │
│                                                              │       │
├── Namespace: temporal                                        │       │
│   │                                                          │       │
│   ├── Secret: cluster-app-user (copied from cnpg-system) ────┘       │
│   │   [Defined in: manifests/secrets/db-credentials-temporal.yaml]   │
│   │                                                                  │
│   ├── Temporal Services:                                             │
│   │   ├── temporal-frontend ───────────────────────────────────────┐ │
│   │   ├── temporal-history ────────────────────────────────────────┼─┘
│   │   ├── temporal-matching ───────────────────────────────────────┤
│   │   ├── temporal-worker ────────────────────────────────────────┐│
│   │   └── temporal-web (UI service)                               ││
│   │       [All defined in: helm-charts/temporal/values.yaml       ││
│   │        and installed via Helm]                                ││
│   │                                                               ││
│   ├── Supporting Services:                                        ││
│   │   ├── temporal-admintools                                     ││
│   │   ├── temporal-schema-job (creates schemas in databases) ─────┘│
│   │   └── temporal-prometheus/grafana (monitoring)                 │
│   │       [All defined in: helm-charts/temporal/values.yaml        │
│   │        and installed via Helm]                                 │
│   │                                                                │
│   └── ConfigMap: temporal-config ────────────────────────────────────┘
│       (contains database connection info)
│       [Created by Helm from helm-charts/temporal/values.yaml]
│
└── Client Access
    └── Port forward to temporal-web and temporal-frontend services
```

## Manifest Files

| Component                     | File Path                                        | Description                                               |
| ----------------------------- | ------------------------------------------------ | --------------------------------------------------------- |
| Temporal Databases            | `manifests/databases/temporal-databases.yaml`    | CloudNative PG Database CR definitions                    |
| Temporal Services             | `helm-charts/temporal/values.yaml`               | Helm values for Temporal deployment                       |
| Database Secret (cnpg-system) | `manifests/secrets/db-credentials.yaml`          | Secret with database credentials in cnpg-system namespace |
| Database Secret (temporal)    | `manifests/secrets/db-credentials-temporal.yaml` | Secret with database credentials in temporal namespace    |

## Connection Flow

1. **Database Setup**: The CloudNative PG operator creates and maintains PostgreSQL databases in the `cnpg-system` namespace
2. **Credentials**: DB username/password are stored in a Kubernetes secret `cluster-app-user`

   * This secret is created in `cnpg-system` namespace and copied to `temporal` namespace
3. **Temporal Configuration**: Temporal services are configured to connect to:

   * Connection URL: `postgresql-cluster-rw.cnpg-system.svc.cluster.local:5432`
   * Credentials: From the `cluster-app-user` secret
   * Database names: `temporal` and `temporal_visibility`
4. **Cross-namespace Access**: Temporal (in `temporal` namespace) connects to PostgreSQL (in `cnpg-system` namespace) using the fully qualified DNS name of the PostgreSQL service

## Prerequisites

* Kubernetes cluster
* Helm installed
* CloudNative PostgreSQL operator installed
* PostgreSQL cluster running via CNPG operator

## Step 0: Install

create cluster

```shell
kind create cluster —name temporal-cnpg
```

add/install repo

```shell
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm pull cnpg/cloudnative-pg untar —destination helm-charts/
helm install cloudnative-pg ./helm-charts/cloudnative-pg —namespace cnpg-system —create-namespace

kubens (-> select ‘cnpg-system’)

k get po
NAME                             READY   STATUS    RESTARTS   AGE
cloudnative-pg-55fb7f5f6-4fd6s   1/1     Running   0          14s

kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg
{"level":"info","ts":"2025-05-13T20:02:40.432227901Z","msg":"Starting Controller","controller":"scheduled-backup","controllerGroup":"postgresql.cnpg.io","controllerKind":"ScheduledBackup"}
{"level":"info","ts":"2025-05-13T20:02:40.432258086Z","msg":"Starting workers","controller":"scheduled-backup","controllerGroup":"postgresql.cnpg.io","controllerKind":"ScheduledBackup","worker count":10}
{"level":"info","ts":"2025-05-13T20:02:40.432627228Z","msg":"Starting Controller","controller":"plugin","controllerGroup":"","controllerKind":"Service"}
{"level":"info","ts":"2025-05-13T20:02:40.432640626Z","msg":"Starting workers","controller":"plugin","controllerGroup":"","controllerKind":"Service","worker count":10}
{"level":"info","ts":"2025-05-13T20:02:40.432672985Z","msg":"Starting Controller","controller":"backup","controllerGroup":"postgresql.cnpg.io","controllerKind":"Backup"}
{"level":"info","ts":"2025-05-13T20:02:40.432676797Z","msg":"Starting workers","controller":"backup","controllerGroup":"postgresql.cnpg.io","controllerKind":"Backup","worker count":1}
{"level":"info","ts":"2025-05-13T20:02:40.433678272Z","msg":"Starting Controller","controller":"cluster","controllerGroup":"postgresql.cnpg.io","controllerKind":"Cluster"}
{"level":"info","ts":"2025-05-13T20:02:40.433693657Z","msg":"Starting workers","controller":"cluster","controllerGroup":"postgresql.cnpg.io","controllerKind":"Cluster","worker count":10}
{"level":"info","ts":"2025-05-13T20:02:40.433729283Z","msg":"Starting Controller","controller":"pooler","controllerGroup":"postgresql.cnpg.io","controllerKind":"Pooler"}
{"level":"info","ts":"2025-05-13T20:02:40.433736251Z","msg":"Starting workers","controller":"pooler","controllerGroup":"postgresql.cnpg.io","controllerKind":"Pooler","worker count":10}

```

create postgres cluster

```shell
k apply -f manifests/secrets/postgresql-secrets.yaml
k apply -f manifests/postgresql/postgresql-cluster.yaml

k get po
NAME                             READY   STATUS    RESTARTS   AGE
cloudnative-pg-55fb7f5f6-2qgll   1/1     Running   0          6m57s
postgresql-cluster-1             1/1     Running   0          114s
postgresql-cluster-2             1/1     Running   0          91s
postgresql-cluster-3             1/1     Running   0          66s

kubectl get service -n cnpg-system | grep postgresql
postgresql-cluster-r    ClusterIP   10.96.132.17    <none>        5432/TCP   57m
postgresql-cluster-ro   ClusterIP   10.96.136.194   <none>        5432/TCP   57m
postgresql-cluster-rw   ClusterIP   10.96.91.167    <none>        5432/TCP   57m
```

## Step 1: Verify CloudNative PostgreSQL Installation

First, check if CloudNative PostgreSQL is properly installed and running:

```bash
# Check the CNPG operator and PostgreSQL cluster
kubectl get pods -n cnpg-system
kubectl get clusters.postgresql -n cnpg-system

# Verify PostgreSQL services
kubectl get service -n cnpg-system | grep postgresql
```

Expected output should show:

* Running PostgreSQL cluster pods
* A cluster resource
* Services including `postgresql-cluster-rw`

## Step 2: Create Database User Secret

The secret files are organized in the `manifests/secrets/` directory:

1. `manifests/secrets/db-credentials.yaml` - Contains credentials for cnpg-system namespace
2. `manifests/secrets/postgres-secrets.yaml` - Contains credentials for temporal namespace

Apply both secret files:

```bash
# Create namespace for Temporal if it doesn't exist
kubectl create namespace temporal --dry-run=client -o yaml | kubectl apply -f -

# Apply the secrets
kubectl apply -f manifests/secrets/db-credentials-temporal.yaml
kubectl apply -f manifests/secrets/postgres-secrets.yaml
```

Verify the secrets were created:

```bash
kubectl get secret cluster-app-user -n cnpg-system
kubectl get secret cluster-app-user -n temporal
```

## Step 3: Create Required Databases Using CloudNative PG

The database definitions are in `manifests/databases/temporal-databases.yaml`.

Apply this configuration to create the databases:

```bash
kubectl apply -f manifests/databases/temporal-databases.yaml
```

Verify the databases were created successfully:

```bash
kubectl get databases.postgresql.cnpg.io -n cnpg-system
```

try connecting to db
Port forward

```shell
kubectl port-forward -n cnpg-system svc/postgresql-cluster-rw 5432:5432
Forwarding from 127.0.0.1:5432 -> 5432
Forwarding from [::1]:5432 -> 5432
```

Now you can connect to PostgreSQL using

```shell
psql "host=localhost port=5432 user=appuser password=appuser-password dbname=appdb"

appdb=> \l
                                  List of databases
        Name         |  Owner   | Encoding | Collate | Ctype |   Access privileges   
---------------------+----------+----------+---------+-------+-----------------------
 appdb               | appuser  | UTF8     | C       | C     | 
 postgres            | postgres | UTF8     | C       | C     | 
 template0           | postgres | UTF8     | C       | C     | =c/postgres          +
                     |          |          |         |       | postgres=CTc/postgres
 template1           | postgres | UTF8     | C       | C     | =c/postgres          +
                     |          |          |         |       | postgres=CTc/postgres
 temporal            | appuser  | UTF8     | C       | C     | 
 temporal_visibility | appuser  | UTF8     | C       | C     | 
(6 rows)
```

## Step 4: Configure Temporal Helm Chart

Create or edit your Temporal values file (`values.yaml`) to configure the connection to PostgreSQL. Key configurations include:

```yaml
# Disable automatic database creation
schema:
  createDatabase:
    enabled: false
  setup:
    enabled: true
  update:
    enabled: true

# Configure persistence to use CloudNative PostgreSQL
server:
  config:
    persistence:
      default:
        driver: "sql"
        sql:
          driver: "postgres12"
          host: postgresql-cluster-rw.cnpg-system.svc.cluster.local
          port: 5432
          database: temporal
          user: appuser
          existingSecret: cluster-app-user
          passwordKey: password
          maxConns: 20
          maxIdleConns: 20
          maxConnLifetime: "1h"
      visibility:
        driver: "sql"
        sql:
          driver: "postgres12"
          host: postgresql-cluster-rw.cnpg-system.svc.cluster.local
          port: 5432
          database: temporal_visibility
          user: appuser
          existingSecret: cluster-app-user
          passwordKey: password
          maxConns: 20
          maxIdleConns: 20
          maxConnLifetime: "1h"
      defaultStore: "default"
      visibilityStore: "visibility"
    namespaces:
      create: true
      namespace:
        - name: default
          retention: 3d
```

The key parts are:

* Disabling database creation since we created them with CNPG
* Configuring the database connections to use the CNPG PostgreSQL service
* Setting up `defaultStore` and `visibilityStore` references
* Enabling namespace creation to create the default namespace

## Step 5: Install Temporal Using Helm

Add the Temporal Helm repository if you haven't already:

```bash
helm repo add temporal https://helm.temporal.io/
helm repo update
```

Install Temporal using your custom values:

```bash
helm install temporal temporal \
  -f values.yaml \
  --namespace temporal \
  --create-namespace
```

## Step 6: Verify Installation

Check that all Temporal pods are running properly:

```bash
kubectl get pods -n temporal
```

All pods should eventually be in `Running` state, except for the schema setup job which should be `Completed`.

Verify that the databases and namespaces were set up correctly:

```bash
# Check schema job logs
kubectl logs -n temporal $(kubectl get pod -n temporal -l app.kubernetes.io/component=schema -o jsonpath="{.items[0].metadata.name}")

# Check namespaces
kubectl exec -it $(kubectl get pod -n temporal -l app.kubernetes.io/name=temporal-admintools -o jsonpath="{.items[0].metadata.name}") -n temporal -- tctl namespace list
```

## Step 7: Access Temporal UI

To access the Temporal UI, set up port forwarding:

```bash
kubectl port-forward svc/temporal-web -n temporal 8080:8080
```

Then open your browser and navigate to [http://localhost:8080](http://localhost:8080).

## Troubleshooting

### Issue: Schema Job Fails

If the schema job fails, check its logs:

```bash
kubectl logs -n temporal $(kubectl get pod -n temporal -l app.kubernetes.io/component=schema -o jsonpath="{.items[0].metadata.name}")
```

### Issue: "Namespace default is not found"

Ensure `namespaces.create` is set to `true` in your values file and redeploy:

```bash
helm upgrade temporal temporal -f values.yaml -n temporal
```

### Issue: Database Connection Problems

Check the logs of the Temporal services:

```bash
kubectl logs -n temporal $(kubectl get pod -n temporal -l app.kubernetes.io/component=frontend -o jsonpath="{.items[0].metadata.name}")
```

Verify the database connectivity by running a PostgreSQL client within the cluster:

```bash
kubectl run pg-client -n cnpg-system --rm --restart=Never -it --image=postgres:14 -- \
  psql -h postgresql-cluster-rw -U appuser -d temporal
```

## Conclusion

You now have Temporal running with CloudNative PostgreSQL as its backend. You can start using Temporal for workflow orchestration by connecting to its frontend service.

For more information on how to use Temporal, refer to the [official documentation](https://docs.temporal.io/).
