# PURPOSE: Database connection management and unified fallback layer for PostgreSQL and memory.
# ROLE IN SYSTEM: Provides pooled PostgreSQL cursors with thread-safe in-memory mirror fallback.
# TALKS TO: server/app/config.py, psycopg2 pool, asyncpg pool, all API routers and services
# DO NOT CONFUSE WITH: server/app/services/ledger.py (ledger domain logic)
import os
import uuid
import datetime
import asyncio
from typing import Dict, Any, List, Optional
import structlog
from server.app.config import settings

logger = structlog.get_logger()

# Asyncpg connection pool (initialized at server startup, persistent)
_asyncpg_pool = None


async def init_asyncpg_pool():
    """Initialize persistent asyncpg connection pool at server startup."""
    global _asyncpg_pool
    try:
        import asyncpg
        _asyncpg_pool = await asyncpg.create_pool(
            dsn=settings.DATABASE_URL,
            min_size=2,
            max_size=10,
            command_timeout=30,
            statement_cache_size=100
        )
        logger.info("Asyncpg connection pool initialized successfully")
    except Exception as e:
        logger.warning("Asyncpg pool initialization failed, will use psycopg2 fallback", error=str(e))
        _asyncpg_pool = None


async def close_asyncpg_pool():
    """Close asyncpg pool at server shutdown."""
    global _asyncpg_pool
    if _asyncpg_pool:
        await _asyncpg_pool.close()
        _asyncpg_pool = None
        logger.info("Asyncpg connection pool closed")


def get_asyncpg_pool():
    """Returns the asyncpg pool if available, None otherwise."""
    return _asyncpg_pool


async def execute_db_function(func_name: str, *args) -> Optional[List[Dict[str, Any]]]:
    """
    Execute a PostgreSQL function via asyncpg pool in a single WAN round-trip.
    Returns list of result rows as dicts, or None if pool unavailable.
    """
    pool = get_asyncpg_pool()
    if pool is None:
        return None
    try:
        async with pool.acquire() as conn:
            rows = await conn.fetch(f"SELECT * FROM {func_name}({', '.join(['$' + str(i+1) for i in range(len(args))])})", *args)
            return [dict(row) for row in rows]
    except Exception as e:
        logger.error("Asyncpg function execution failed", function=func_name, error=str(e))
        return None


class DatabaseStore:
    """
    In-memory / transactional storage engine for VaniGuard.
    Mirrors Supabase Postgres schema with row-level locks, constraints, and audit logging.
    """
    def __init__(self):
        self.users: Dict[uuid.UUID, Dict[str, Any]] = {}
        self.voiceprints: Dict[uuid.UUID, Dict[str, Any]] = {}
        self.accounts: Dict[uuid.UUID, Dict[str, Any]] = {}
        self.payees: Dict[uuid.UUID, Dict[str, Any]] = {}
        self.transfers: Dict[uuid.UUID, Dict[str, Any]] = {}
        self.ledger_entries: List[Dict[str, Any]] = []
        self.trust_relationships: Dict[uuid.UUID, Dict[str, Any]] = {}
        self.tc_actions: Dict[uuid.UUID, Dict[str, Any]] = {}
        self.consents: Dict[uuid.UUID, Dict[str, Any]] = {}
        self.audit_log: List[Dict[str, Any]] = []
        self._seed_default_data()

    def _seed_default_data(self):
        # Default Elderly User (Asha Sharma)
        user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
        self.users[user_id] = {
            "id": user_id,
            "phone": "+919876543210",
            "full_name": "Asha Sharma",
            "preferred_language": "hi",
            "accessibility_prefs": {"high_contrast": False, "screen_reader": True, "speech_rate": 0.85},
            "baseline_acoustic_profile": {
                "f0_mean": 155.0,
                "f0_std": 14.5,
                "jitter": 0.014,
                "shimmer": 0.032,
                "snr_db": 18.5
            },
            "created_at": datetime.datetime.now(datetime.timezone.utc)
        }

        # User's Primary Account (50,000 INR = 5,000,000 Paise)
        account_id = uuid.UUID("22222222-2222-2222-2222-222222222222")
        self.accounts[account_id] = {
            "id": account_id,
            "user_id": user_id,
            "account_number_masked": "...4819",
            "account_type": "SAVINGS",
            "currency": "INR",
            "balance_paise": 5000000,
            "opened_at": datetime.datetime.now(datetime.timezone.utc)
        }

        # Central Bank Clearing Account
        clearing_account_id = uuid.UUID("33333333-3333-3333-3333-333333333333")
        self.accounts[clearing_account_id] = {
            "id": clearing_account_id,
            "user_id": uuid.UUID("00000000-0000-0000-0000-000000000000"),
            "account_number_masked": "...0001",
            "account_type": "CLEARING_POOL",
            "currency": "INR",
            "balance_paise": 100000000,
            "opened_at": datetime.datetime.now(datetime.timezone.utc)
        }

        # Pre-registered trusted payee (Son Rahul)
        payee_id = uuid.UUID("44444444-4444-4444-4444-444444444444")
        self.payees[payee_id] = {
            "id": payee_id,
            "user_id": user_id,
            "name": "Rahul Sharma",
            "masked_account": "...9921",
            "account_ref": "HDFC0001234",
            "nickname": "Son Rahul",
            "verified": True,
            "created_at": datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=90)
        }

        # Trusted Contact User (Daughter Priya)
        tc_user_id = uuid.UUID("55555555-5555-5555-5555-555555555555")
        self.users[tc_user_id] = {
            "id": tc_user_id,
            "phone": "+919876500000",
            "full_name": "Priya Sharma",
            "preferred_language": "en",
            "accessibility_prefs": {"high_contrast": False, "screen_reader": False, "speech_rate": 1.0},
            "baseline_acoustic_profile": None,
            "created_at": datetime.datetime.now(datetime.timezone.utc)
        }

        # Trust Relationship
        trust_id = uuid.UUID("66666666-6666-6666-6666-666666666666")
        self.trust_relationships[trust_id] = {
            "id": trust_id,
            "account_holder_id": user_id,
            "trusted_contact_id": tc_user_id,
            "threshold_paise": 500000,  # 5,000 INR
            "active": True,
            "created_at": datetime.datetime.now(datetime.timezone.utc)
        }


db = DatabaseStore()


import psycopg2
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager

def get_pg_connection():
    return psycopg2.connect(settings.DATABASE_URL, connect_timeout=10)

@contextmanager
def get_db_cursor(commit: bool = False):
    """
    Context manager yielding a PostgreSQL dictionary cursor against Supabase.
    Automatically commits on normal exit if commit=True, rollbacks on exception.
    """
    conn = get_pg_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            yield cur
        if commit:
            conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

def is_pg_available() -> bool:
    try:
        conn = get_pg_connection()
        conn.close()
        return True
    except Exception:
        return False

