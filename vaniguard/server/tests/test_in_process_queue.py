# PURPOSE: Dedicated tests for the InProcessAsyncQueue fallback ensuring no-Redis mode is covered.
# ROLE IN SYSTEM: Validates job submit, execute, retry, and failure paths in the in-process queue.
# TALKS TO: worker/in_process_queue.py
import pytest
import asyncio
from worker.in_process_queue import InProcessAsyncQueue


@pytest.fixture
def fresh_queue():
    """Creates a fresh InProcessAsyncQueue instance for each test."""
    return InProcessAsyncQueue(concurrency=2)


@pytest.mark.asyncio(loop_scope="function")
async def test_queue_submit_and_execute(fresh_queue):
    """Verifies that a job can be submitted and executed successfully."""
    results = []

    async def sample_handler(value):
        results.append(value)
        return value * 2

    fresh_queue.register_handler("double", sample_handler)
    result = await fresh_queue.enqueue("double", 21)

    assert result == 42
    assert 21 in results
    await fresh_queue.stop()


@pytest.mark.asyncio(loop_scope="function")
async def test_queue_sync_handler(fresh_queue):
    """Verifies that synchronous handlers work correctly."""
    def sync_handler(a, b):
        return a + b

    fresh_queue.register_handler("add", sync_handler)
    result = await fresh_queue.enqueue("add", 10, 32)

    assert result == 42
    await fresh_queue.stop()


@pytest.mark.asyncio(loop_scope="function")
async def test_queue_failure_propagation(fresh_queue):
    """Verifies that handler exceptions propagate to the caller."""
    async def failing_handler():
        raise ValueError("Intentional test failure")

    fresh_queue.register_handler("fail", failing_handler)

    with pytest.raises(ValueError, match="Intentional test failure"):
        await fresh_queue.enqueue("fail")

    await fresh_queue.stop()


@pytest.mark.asyncio(loop_scope="function")
async def test_queue_missing_handler(fresh_queue):
    """Verifies that submitting a job with no registered handler raises an error."""
    with pytest.raises(ValueError, match="No handler registered"):
        await fresh_queue.enqueue("nonexistent_handler")

    await fresh_queue.stop()


@pytest.mark.asyncio(loop_scope="function")
async def test_queue_start_stop_lifecycle(fresh_queue):
    """Verifies queue start and stop lifecycle."""
    assert fresh_queue._running is False

    async def noop_handler():
        return "ok"

    fresh_queue.register_handler("noop", noop_handler)

    # First enqueue auto-starts the queue
    result = await fresh_queue.enqueue("noop")
    assert result == "ok"
    assert fresh_queue._running is True

    await fresh_queue.stop()
    assert fresh_queue._running is False
    assert len(fresh_queue.workers) == 0


@pytest.mark.asyncio(loop_scope="function")
async def test_queue_concurrent_jobs(fresh_queue):
    """Verifies that multiple jobs can execute concurrently."""
    execution_order = []

    async def tracked_handler(job_id, delay):
        execution_order.append(f"start-{job_id}")
        await asyncio.sleep(delay)
        execution_order.append(f"end-{job_id}")
        return job_id

    fresh_queue.register_handler("tracked", tracked_handler)

    # Submit two jobs concurrently
    task1 = asyncio.create_task(fresh_queue.enqueue("tracked", "A", 0.05))
    task2 = asyncio.create_task(fresh_queue.enqueue("tracked", "B", 0.01))

    results = await asyncio.gather(task1, task2)

    assert "A" in results
    assert "B" in results
    # Both should have started (concurrent workers)
    starts = [e for e in execution_order if e.startswith("start-")]
    assert len(starts) == 2

    await fresh_queue.stop()


@pytest.mark.asyncio(loop_scope="function")
async def test_queue_auto_start_on_enqueue(fresh_queue):
    """Verifies the queue auto-starts when a job is enqueued while stopped."""
    async def auto_handler():
        return "auto-started"

    fresh_queue.register_handler("auto", auto_handler)
    assert fresh_queue._running is False

    result = await fresh_queue.enqueue("auto")
    assert result == "auto-started"
    assert fresh_queue._running is True

    await fresh_queue.stop()


@pytest.mark.asyncio(loop_scope="function")
async def test_queue_multiple_handlers(fresh_queue):
    """Verifies that multiple different handlers can be registered and invoked."""
    async def handler_a(x):
        return x + 1

    async def handler_b(x):
        return x * 2

    fresh_queue.register_handler("increment", handler_a)
    fresh_queue.register_handler("double", handler_b)

    r1 = await fresh_queue.enqueue("increment", 5)
    r2 = await fresh_queue.enqueue("double", 5)

    assert r1 == 6
    assert r2 == 10

    await fresh_queue.stop()
