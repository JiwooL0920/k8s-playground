from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from temporalio.client import Client
import uuid
import logging

from app.workflows.workflow import GreetingWorkflow
from app.dependencies import get_temporal_client

router = APIRouter(prefix="/workflows", tags=["workflows"])
logger = logging.getLogger(__name__)


class GreetingRequest(BaseModel):
    name: str


class WorkflowResponse(BaseModel):
    workflow_id: str
    message: str


@router.post("/greeting", response_model=WorkflowResponse)
async def start_greeting_workflow(
    request: GreetingRequest, 
    client: Client = Depends(get_temporal_client)
):
    # Generate a unique workflow ID
    workflow_id = f"greeting-{uuid.uuid4()}"
    
    try:
        logger.info(f"Starting workflow with ID: {workflow_id}")
        
        # Start the workflow with the correct arguments pattern
        handle = await client.start_workflow(
            GreetingWorkflow.run,
            request.name,  # Single argument, no need for args=[]
            id=workflow_id,
            task_queue="greeting-task-queue",
        )
        
        logger.info(f"Workflow started, waiting for result")
        
        # Wait for the result
        result = await handle.result()
        
        logger.info(f"Workflow completed with result: {result}")
        
        return WorkflowResponse(
            workflow_id=workflow_id,
            message=result
        )
    except Exception as e:
        logger.error(f"Error executing workflow: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500, 
            detail=f"Failed to execute workflow: {str(e)}"
        ) 