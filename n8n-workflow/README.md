# n8n on Kubernetes with SQLite

This setup provides a local development environment for n8n workflow automation tool running on Kubernetes (kind) with SQLite database.

## Prerequisites

- Docker
- [kind](https://kind.sigs.k8s.io/) - Kubernetes in Docker
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes command-line tool
- [Helm](https://helm.sh/docs/intro/install/) - Kubernetes package manager

## Directory Structure

```
n8n-workflow/
├── helm-charts/           # Helm chart files
│   ├── n8n-helm-chart/    # n8n Helm chart (cloned from GitHub)
│   ├── n8n-values.yaml    # Custom values for n8n
│   └── pv.yaml            # Persistent Volume definition
├── kind-config.yaml       # kind cluster configuration
├── scripts/               # Automation scripts
│   ├── setup-n8n.sh       # Setup script
│   └── cleanup-n8n.sh     # Cleanup script
├── Makefile               # Commands for common operations
└── README.md              # This file
```

## Quick Start

### Using Makefile (Recommended)

```bash
# Set up n8n with SQLite
make setup

# Check status
make status

# View logs
make logs

# See all available commands
make help
```

### Using Scripts Directly

1. Make scripts executable:
   ```bash
   chmod +x n8n-workflow/scripts/setup-n8n.sh
   chmod +x n8n-workflow/scripts/cleanup-n8n.sh
   ```

2. Set up n8n:
   ```bash
   ./n8n-workflow/scripts/setup-n8n.sh
   ```

3. Access n8n:
   
   Once the setup is complete, access n8n at: http://localhost:5678

## Makefile Commands

The Makefile provides the following commands for easier management:

- `make setup` - Set up n8n with SQLite
- `make cleanup` - Clean up n8n and related resources
- `make status` - Check status of n8n pods and services
- `make logs` - View n8n logs
- `make port-forward` - Forward n8n service to localhost
- `make restart` - Restart n8n pods
- `make recreate-pod` - Delete and recreate the n8n pod
- `make help` - Show help information

## Configuration

The main configuration is in `helm-charts/n8n-values.yaml`. Key configuration options:

- Database: SQLite (lightweight file-based database)
- Persistence: Enabled for n8n data (1Gi)
- Service: NodePort type with port mapping to 5678 on localhost

## Notes

- This setup uses SQLite for simplicity in local development
- All data is persisted in volumes
- For production use, consider PostgreSQL and additional configurations for security, backups, and high availability
- The setup-n8n.sh script automatically sets up port-forwarding for you

## Cleanup

To remove the n8n installation and related resources:

```bash
# Using Makefile
make cleanup

# Or using script directly
./n8n-workflow/scripts/cleanup-n8n.sh
```

This will:
1. Uninstall the n8n Helm release
2. Delete PVCs and PVs
3. Delete the n8n namespace
4. Optionally delete the kind cluster 