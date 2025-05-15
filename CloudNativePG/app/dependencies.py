import os
from typing import Optional, Callable, Awaitable
from temporalio.client import Client
from dotenv import load_dotenv
import asyncio

# Load environment variables
load_dotenv()

# Singleton Temporal client instance
_client_instance: Optional[Client] = None
_client_lock = asyncio.Lock()

async def get_temporal_client() -> Client:
    """
    Returns a singleton Temporal client.
    """
    global _client_instance
    
    # Use a lock to prevent multiple simultaneous client creation
    async with _client_lock:
        if _client_instance is None:
            # Get Temporal server address from environment or use default
            temporal_address = os.getenv("TEMPORAL_ADDRESS", "localhost:7233")
            
            # Create a client connected to the Temporal server
            _client_instance = await Client.connect(temporal_address)
            
    return _client_instance 