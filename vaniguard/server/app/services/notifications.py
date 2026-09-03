# PURPOSE: Real-time WebSocket push notification manager connecting mobile clients for instant alerts.
# ROLE IN SYSTEM: Dispatches circuit break alerts to guardians and ledger state syncs to both parties.
# TALKS TO: server/app/api/v1/websocket.py, server/app/api/v1/tc_actions.py, server/app/api/v1/transfers.py
import json
import uuid
import datetime
import asyncio
from typing import Dict, Set, Optional, Any
from fastapi import WebSocket
import structlog
from server.app.database import db, is_pg_available, get_db_cursor

logger = structlog.get_logger()


class NotificationManager:
    """Manages active WebSocket connections by user_id for multi-device push synchronization."""

    def __init__(self):
        self._connections: Dict[uuid.UUID, Set[WebSocket]] = {}
        self._lock = asyncio.Lock()

    async def register(self, user_id: uuid.UUID, websocket: WebSocket):
        async with self._lock:
            if user_id not in self._connections:
                self._connections[user_id] = set()
            self._connections[user_id].add(websocket)
        logger.info("Notification client registered", user_id=str(user_id), active_clients=len(self._connections[user_id]))

    async def unregister(self, user_id: uuid.UUID, websocket: WebSocket):
        async with self._lock:
            if user_id in self._connections:
                self._connections[user_id].discard(websocket)
                if not self._connections[user_id]:
                    del self._connections[user_id]
        logger.info("Notification client unregistered", user_id=str(user_id))

    async def broadcast_to_user(self, user_id: uuid.UUID, event_type: str, payload: Dict[str, Any]):
        """Dispatches an event payload to all active WebSockets for a given user."""
        targets = set()
        async with self._lock:
            if user_id in self._connections:
                targets = set(self._connections[user_id])

        if not targets:
            logger.info("No active notification client for user", user_id=str(user_id), event_type=event_type)
            return

        message = {
            "type": event_type,
            "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            **payload
        }

        dead_connections = []
        for ws in targets:
            try:
                await ws.send_json(message)
            except Exception as e:
                logger.warning("Failed to deliver notification message", error=str(e), user_id=str(user_id))
                dead_connections.append(ws)

        if dead_connections:
            async with self._lock:
                for ws in dead_connections:
                    if user_id in self._connections:
                        self._connections[user_id].discard(ws)

    async def notify_circuit_break(
        self,
        holder_id: uuid.UUID,
        transfer_id: uuid.UUID,
        amount_paise: int,
        payee_name: str,
        risk_score: int,
        cooling_minutes: int = 30
    ):
        """Immediately notifies the designated guardian and holder of a CIRCUIT_BREAK hold."""
        guardian_id = None

        # Check DB first
        if is_pg_available():
            try:
                with get_db_cursor() as cur:
                    cur.execute("""
                        SELECT trusted_contact_id, cooling_window_minutes
                        FROM trust_relationships
                        WHERE account_holder_id = %s AND active = TRUE
                        LIMIT 1;
                    """, (str(holder_id),))
                    row = cur.fetchone()
                    if row:
                        guardian_id = uuid.UUID(str(row["trusted_contact_id"]))
                        cooling_minutes = row["cooling_window_minutes"]
            except Exception:
                pass

        if not guardian_id:
            for tr in db.trust_relationships.values():
                if tr["account_holder_id"] == holder_id and tr["active"]:
                    guardian_id = tr["trusted_contact_id"]
                    cooling_minutes = tr.get("cooling_window_minutes", 30)
                    break

        holder = db.users.get(holder_id, {})
        holder_name = holder.get("full_name", "Account Holder")

        alert_payload = {
            "transfer_id": str(transfer_id),
            "account_holder_id": str(holder_id),
            "account_holder_name": holder_name,
            "amount_paise": amount_paise,
            "amount_inr": amount_paise / 100.0,
            "payee_name": payee_name,
            "risk_score": risk_score,
            "cooling_minutes": cooling_minutes,
            "status": "HELD"
        }

        # 1. Notify Guardian with alert card event
        if guardian_id:
            logger.info("Pushing circuit_break_alert to guardian", guardian_id=str(guardian_id), transfer_id=str(transfer_id))
            await self.broadcast_to_user(guardian_id, "circuit_break_alert", alert_payload)

        # 2. Notify Holder
        await self.broadcast_to_user(holder_id, "transfer_held", alert_payload)

    async def notify_transfer_status(
        self,
        transfer_id: uuid.UUID,
        status: str,  # "transfer_completed" or "transfer_cancelled"
        holder_id: uuid.UUID,
        tc_id: Optional[uuid.UUID],
        amount_paise: int,
        payee_name: str
    ):
        """Broadcasts transfer state changes to both holder and trusted contact to trigger live balance refetch."""
        payload = {
            "transfer_id": str(transfer_id),
            "status": status,
            "amount_paise": amount_paise,
            "amount_inr": amount_paise / 100.0,
            "payee_name": payee_name
        }

        # Notify holder
        await self.broadcast_to_user(holder_id, status, payload)

        # Notify trusted contact / guardian if present
        if tc_id:
            await self.broadcast_to_user(tc_id, status, payload)


notification_manager = NotificationManager()
