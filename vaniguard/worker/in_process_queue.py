import asyncio
import uuid
from typing import Any, Callable, Dict, Optional
import structlog

logger = structlog.get_logger()


class InProcessAsyncQueue:
    """
    Lightweight in-process async task queue.
    Used as resilient fallback when Redis binary / server is unreachable.
    Executes tasks in background asyncio tasks without crashing the application.
    """
    def __init__(self, concurrency: int = 4):
        self.concurrency = concurrency
        self.queue: asyncio.Queue = asyncio.Queue()
        self.results: Dict[str, asyncio.Future] = {}
        self.workers = []
        self._running = False
        self._handlers: Dict[str, Callable] = {}

    def register_handler(self, name: str, handler: Callable):
        self._handlers[name] = handler

    async def start(self):
        if self._running:
            return
        self._running = True
        for i in range(self.concurrency):
            worker_task = asyncio.create_task(self._worker_loop(i))
            self.workers.append(worker_task)
        logger.info("In-process async queue started", workers=self.concurrency)

    async def stop(self):
        self._running = False
        for _ in self.workers:
            await self.queue.put(None)
        await asyncio.gather(*self.workers, return_exceptions=True)
        self.workers.clear()
        logger.info("In-process async queue stopped")

    async def _worker_loop(self, worker_id: int):
        while self._running:
            item = await self.queue.get()
            if item is None:
                self.queue.task_done()
                break
            job_id, func_name, args, kwargs = item
            fut = self.results.get(job_id)
            handler = self._handlers.get(func_name)
            if not handler:
                if fut and not fut.done():
                    fut.set_exception(ValueError(f"No handler registered for '{func_name}'"))
                self.queue.task_done()
                continue

            try:
                res = handler(*args, **kwargs)
                if asyncio.iscoroutine(res):
                    res = await res
                if fut and not fut.done():
                    fut.set_result(res)
            except Exception as e:
                logger.error("Job execution error", job_id=job_id, error=str(e))
                if fut and not fut.done():
                    fut.set_exception(e)
            finally:
                self.queue.task_done()

    async def enqueue(self, func_name: str, *args, **kwargs) -> Any:
        if not self._running:
            await self.start()
        job_id = str(uuid.uuid4())
        loop = asyncio.get_running_loop()
        fut = loop.create_future()
        self.results[job_id] = fut
        await self.queue.put((job_id, func_name, args, kwargs))
        return await fut


in_process_queue = InProcessAsyncQueue()
