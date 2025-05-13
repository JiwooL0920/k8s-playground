from temporalio import activity


@activity.defn
async def say_hello(name: str) -> str:
    activity.logger.info(f"Running activity with {name}")
    return f"Hello, {name}!" 