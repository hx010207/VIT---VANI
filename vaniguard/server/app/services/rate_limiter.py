# PURPOSE: In-memory sliding-window rate limiter and challenge failure escalation engine.
# ROLE IN SYSTEM: Guards login, challenge, transfer, and TC review endpoints against brute force and replay.
# TALKS TO: server/app/api/v1/auth.py, server/app/api/v1/voice.py, server/app/api/v1/transfers.py, server/app/services/notifications.py
import time
import uuid
import datetime
from collections import defaultdict
from typing import Dict, List
import structlog
from server.app.services.notifications import notification_manager

logger = structlog.get_logger()


class RateLimiter:
    """Sliding-window in-memory rate limiter with automated coercion escalation."""

    def __init__(self):
        self._requests: Dict[str, List[float]] = defaultdict(list)
        self._failed_challenges: Dict[str, List[float]] = defaultdict(list)

    def is_allowed(self, key: str, max_limit: int, window_seconds: int = 60) -> bool:
        """Evaluates whether the request is within the rate limit window."""
        now = time.time()
        cutoff = now - window_seconds
        # Clean older entries
        self._requests[key] = [t for t in self._requests[key] if t > cutoff]

        if len(self._requests[key]) >= max_limit:
            logger.warning("Rate limit exceeded", key=key, count=len(self._requests[key]), max_limit=max_limit)
            return False

        self._requests[key].append(now)
        return True

    async def record_failed_challenge(self, account_holder_id: uuid.UUID) -> int:
        """
        Records a failed spoken challenge.
        After 3 failed challenge attempts in a 10-minute window, enforces an immediate CIRCUIT_BREAK hold
        and pushes an emergency alert to the designated guardian.
        """
        now = time.time()
        cutoff = now - 600  # 10 minutes
        user_key = str(account_holder_id)
        self._failed_challenges[user_key] = [t for t in self._failed_challenges[user_key] if t > cutoff]
        self._failed_challenges[user_key].append(now)

        fail_count = len(self._failed_challenges[user_key])
        logger.info("Spoken challenge failure recorded", user_id=user_key, fail_count=fail_count)

        if fail_count >= 3:
            logger.error("Three consecutive spoken challenge failures. Escalating to protective CIRCUIT_BREAK hold.", user_id=user_key)
            alert_id = uuid.uuid4()
            await notification_manager.notify_circuit_break(
                holder_id=account_holder_id,
                transfer_id=alert_id,
                amount_paise=0,
                payee_name="Security Forced Hold (3 Failed Spoken Challenges)",
                risk_score=95,
                cooling_minutes=30
            )

        return fail_count

    def reset_failed_challenges(self, account_holder_id: uuid.UUID):
        """Clears failed challenge history upon a successful verification."""
        user_key = str(account_holder_id)
        self._failed_challenges.pop(user_key, None)


rate_limiter = RateLimiter()
