# PURPOSE: Background asynchronous sweeper for expired cooling windows on held transfers.
# ROLE IN SYSTEM: Periodically checks HELD transfers and auto-cancels those exceeding 30 minutes.
# TALKS TO: server/app/database.py, server/app/services/audit.py, server/app/main.py
# DO NOT CONFUSE WITH: worker/worker.py (general distributed job worker)
import asyncio
import datetime
import structlog
from typing import List
from server.app.database import db
from server.app.models.schemas import TransferStateEnum
from server.app.services.audit import audit_service
from server.app.config import settings

logger = structlog.get_logger()


class CoolingWindowSweeper:
    """
    Background worker service that monitors transfers held under the circuit-break protocol.
    Automatically expires and cancels held transfers once their cooling window has elapsed,
    preventing transactions from lingering in an indeterminate state.
    """
    def __init__(self, check_interval_seconds: int = settings.SWEEPER_INTERVAL_SECONDS):
        self.check_interval_seconds = check_interval_seconds
        self._running = False
        self._task = None

    def sweep_expired_transfers(self) -> List[str]:
        """
        Synchronous / batch sweep function.
        Identifies all expired HELD transfers and cancels them with audit entries.
        """
        now = datetime.datetime.now(datetime.timezone.utc)
        cancelled_ids = []

        from server.app.database import is_pg_available, get_db_cursor
        if is_pg_available():
            try:
                with get_db_cursor(commit=True) as cur:
                    cur.execute("""
                        UPDATE transfers
                        SET state = 'CANCELLED', final_at = %s
                        WHERE state = 'HELD' AND cooling_expires_at <= %s
                        RETURNING id, created_at, cooling_expires_at;
                    """, (now, now))
                    rows = cur.fetchall()
                    if rows:
                        for r in rows:
                            tid = str(r["id"])
                            cancelled_ids.append(tid)
                            audit_service.log(
                                actor_id="system:cooling_sweeper",
                                entity="transfers",
                                entity_id=tid,
                                action="COOLING_EXPIRED_AUTO_CANCEL",
                                payload={"auto_cancelled_at": now.isoformat()},
                                request_id=f"sweep-{int(now.timestamp())}"
                            )
                            logger.info("Auto-cancelled expired held transfer in DB", transfer_id=tid)
            except Exception as e:
                logger.error("Error sweeping expired transfers in PostgreSQL", error=str(e))

        for transfer_id, transfer in db.transfers.items():
            if transfer["state"] == TransferStateEnum.HELD:
                expires_at = transfer.get("cooling_expires_at")
                if expires_at and expires_at <= now:
                    transfer["state"] = TransferStateEnum.CANCELLED
                    transfer["final_at"] = now
                    cancelled_ids.append(str(transfer_id))

                    audit_service.log(
                        actor_id="system:cooling_sweeper",
                        entity="transfers",
                        entity_id=str(transfer_id),
                        action="COOLING_EXPIRED_AUTO_CANCEL",
                        payload={
                            "held_since": transfer["created_at"].isoformat(),
                            "expired_at": expires_at.isoformat(),
                            "auto_cancelled_at": now.isoformat()
                        },
                        request_id=f"sweep-{int(now.timestamp())}"
                    )
                    logger.info("Auto-cancelled expired held transfer", transfer_id=str(transfer_id))

        return cancelled_ids

    async def start_loop(self):
        """Starts the periodic background sweeping task."""
        self._running = True
        logger.info("Starting CoolingWindowSweeper background loop", interval_sec=self.check_interval_seconds)
        while self._running:
            try:
                await asyncio.to_thread(self.sweep_expired_transfers)
            except Exception as e:
                logger.error("Error in cooling window sweeper loop", error=str(e))
            await asyncio.sleep(self.check_interval_seconds)

    def stop(self):
        self._running = False
        if self._task and not self._task.done():
            self._task.cancel()


cooling_sweeper = CoolingWindowSweeper()
