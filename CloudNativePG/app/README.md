# FastAPI with Temporal Workflows

This simple FastAPI application demonstrates how to integrate with Temporal for workflow orchestration. The app provides an endpoint to start a simple greeting workflow.

## Features

- FastAPI REST API
- Temporal workflow integration
- Kubernetes deployment configuration

## Architecture

The application consists of:

- **FastAPI Backend**: Handles HTTP requests and starts Temporal workflows
- **Temporal Worker**: Runs within the same process to execute workflow and activity code
- **Kubernetes Deployment**: For scalable deployment

## Project Structure

```
app/
├── activities/             # Temporal activities
│   ├── __init__.py
│   └── activity.py         # Contains the 'say_hello' activity
├── api/                    # FastAPI routes
│   ├── __init__.py
│   └── router.py           # Workflow API endpoints
├── workflows/              # Temporal workflows
│   ├── __init__.py
│   └── workflow.py         # Contains the 'GreetingWorkflow'
├── __init__.py
├── dependencies.py         # Temporal client dependency
├── main.py                 # FastAPI application entry point
├── requirements.txt        # Application dependencies
├── Dockerfile              # Container definition
└── build-and-deploy.sh     # Deployment script
```

## How It Works

### Temporal Integration

1. **Client Connection**: The app establishes a connection to the Temporal server using the `get_temporal_client()` dependency.
2. **Worker Registration**: When the FastAPI app starts, it registers the workflows and activities with Temporal via a Worker.
3. **Workflow Execution**: When a request is made to `/workflows/greeting`, the app starts a new Temporal workflow.

### Kubernetes Deployment

The application is deployed as a single pod in Kubernetes that contains both:
- The FastAPI web server
- An embedded Temporal worker

### Workflow & Activity Communication

1. The workflow (`GreetingWorkflow`) receives a name input
2. It executes the activity (`say_hello`) with the name
3. The activity returns a greeting message
4. The workflow completes and returns the result

## Prerequisites

- Docker
- Kubernetes (kind cluster)
- Temporal server running in the cluster (see [../SETUP.md](../SETUP.md))

## Development & Deployment Workflow

### 1. Initial Setup

Make sure your kind cluster is running and Temporal is installed:

```bash
# Check if kind cluster is running
kind get clusters

# Check if Temporal is deployed
kubectl get pods -n temporal
```

### 2. Making Changes

When you make changes to the application code:

1. Edit the files you need to change:
   - For workflows: modify `app/workflows/workflow.py`
   - For activities: modify `app/activities/activity.py`
   - For API endpoints: modify `app/api/router.py`

2. Build and deploy the changes:

   ```bash
   # Make the deployment script executable (first time only)
   chmod +x build-and-deploy.sh
   
   # Build and deploy
   ./build-and-deploy.sh
   ```

3. Restart the deployment to apply changes:

   ```bash
   # Restart the deployment
   kubectl rollout restart deployment fastapi-temporal -n temporal
   
   # Wait for the rollout to complete
   kubectl rollout status deployment fastapi-temporal -n temporal
   ```

4. Check the logs to verify everything is working:

   ```bash
   # View the logs
   kubectl logs -n temporal -l app=fastapi-temporal --tail=50
   ```

### 3. Accessing Your Application

1. Forward the application port to your local machine:

   ```bash
   # If port 8000 is available
   kubectl port-forward -n temporal svc/fastapi-temporal 8000:8000
   
   # If port 8000 is already in use
   kubectl port-forward -n temporal svc/fastapi-temporal 8001:8000
   ```

2. Access the application:
   - Swagger UI: http://localhost:8000/docs (or http://localhost:8001/docs)
   - API endpoint: http://localhost:8000/workflows/greeting (or http://localhost:8001/workflows/greeting)

### 4. Managing Port Forwards

If port-forward fails because the port is already in use:

1. Find the process using the port:
   ```bash
   lsof -i :8000 | grep LISTEN
   ```

2. Terminate the process:
   ```bash
   kill <PID>
   ```

3. Or use a different port:
   ```bash
   kubectl port-forward -n temporal svc/fastapi-temporal 8001:8000
   ```

### 5. Troubleshooting

If your application isn't working as expected:

1. Check the application logs:
   ```bash
   kubectl logs -n temporal -l app=fastapi-temporal
   ```

2. Check if the Temporal frontend service is accessible:
   ```bash
   kubectl get svc -n temporal | grep frontend
   ```

3. Check if your Temporal namespace exists:
   ```bash
   kubectl exec -it $(kubectl get pod -n temporal -l app.kubernetes.io/name=temporal-admintools -o jsonpath="{.items[0].metadata.name}") -n temporal -- tctl namespace list
   ```

## API Usage

### Greeting Workflow

- **Endpoint**: POST /workflows/greeting
- **Request body**:
  ```json
  {
    "name": "Your Name"
  }
  ```
- **Response**:
  ```json
  {
    "workflow_id": "greeting-uuid",
    "message": "Hello, Your Name!"
  }
  ```

## Advanced Development

### Local Development

For local development without Kubernetes:

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Set the Temporal address environment variable:
   ```bash
   export TEMPORAL_ADDRESS="localhost:7233"
   ```

3. Run the application:
   ```bash
   uvicorn app.main:app --reload
   ```

### Customizing the Deployment

To modify the Kubernetes deployment:

1. Edit the deployment manifest:
   ```bash
   kubectl edit deployment fastapi-temporal -n temporal
   ```

2. Or modify `manifests/app/fastapi-deployment.yaml` and apply the changes:
   ```bash
   kubectl apply -f ../manifests/app/fastapi-deployment.yaml
   ``` 