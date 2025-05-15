import asyncio
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
import logging
import os
from temporalio.client import Client
from temporalio.worker import Worker

from app.api.router import router as workflows_router
from app.dependencies import get_temporal_client
from app.workflows.workflow import GreetingWorkflow
from app.activities.activity import say_hello

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="Temporal FastAPI Demo",
    description="A simple FastAPI app that uses Temporal for workflows",
    version="0.1.0",
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(workflows_router)


# Worker task that registers workflows and activities with Temporal
worker_task = None
worker_instance = None


@app.on_event("startup")
async def startup_event():
    """
    Start the Temporal worker when the FastAPI app starts up.
    """
    global worker_task, worker_instance
    
    # Get Temporal client
    temporal_address = os.getenv("TEMPORAL_ADDRESS", "localhost:7233")
    logger.info(f"Connecting to Temporal at {temporal_address}")
    
    try:
        # Connect to Temporal server
        client = await get_temporal_client()
        logger.info("Connected to Temporal server")
        
        # Create a worker that handles workflow and activity tasks
        logger.info("Starting Temporal worker...")
        worker_instance = Worker(
            client,
            task_queue="greeting-task-queue",
            workflows=[GreetingWorkflow],
            activities=[say_hello],
        )
        
        # Start the worker
        worker_task = asyncio.create_task(worker_instance.run())
        logger.info("Temporal worker started")
    except Exception as e:
        logger.error(f"Failed to start Temporal worker: {str(e)}", exc_info=True)
        # Continue running the app even if Temporal connection fails
        # This allows the health check to work


@app.on_event("shutdown")
async def shutdown_event():
    """
    Stop the Temporal worker when the FastAPI app shuts down.
    """
    global worker_task, worker_instance
    if worker_task:
        logger.info("Stopping Temporal worker...")
        worker_task.cancel()
        try:
            await worker_task
        except asyncio.CancelledError:
            pass
        logger.info("Temporal worker stopped")


@app.get("/health")
async def health_check():
    """
    Health check endpoint.
    """
    return {"status": "healthy"} 