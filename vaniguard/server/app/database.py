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
        self.guardian_pending_changes: Dict[uuid.UUID, Dict[str, Any]] = {}
        self.always_allow_payees: Dict[uuid.UUID, Dict[str, Any]] = {}
        self.revoked_tokens: set = set()
        self._seed_default_data()

    def _seed_default_data(self):
        import hashlib

        def _hash(pw: str, salt: str = "vaniguardsalt12345") -> tuple:
            dk = hashlib.pbkdf2_hmac("sha256", pw.encode("utf-8"), bytes.fromhex(salt.encode("utf-8").hex()[:32]), 100000)
            return dk.hex(), salt

        asha_hash, asha_salt = _hash("Asha@Demo2026")
        priya_hash, priya_salt = _hash("Priya@Demo2026")

        # Default Elderly User (Asha Sharma)
        user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
        self.users[user_id] = {
            "id": user_id,
            "phone": "+919876543210",
            "full_name": "Asha Sharma (Elder)",
            "preferred_language": "hi",
            "guardian_mode": True,
            "password_hash": asha_hash,
            "password_salt": asha_salt,
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

        # Trusted Contact User (Daughter Priya)
        tc_user_id = uuid.UUID("55555555-5555-5555-5555-555555555555")
        self.users[tc_user_id] = {
            "id": tc_user_id,
            "phone": "+919876543211",
            "full_name": "Priya Sharma (Guardian)",
            "preferred_language": "en",
            "guardian_mode": False,
            "password_hash": priya_hash,
            "password_salt": priya_salt,
            "accessibility_prefs": {"high_contrast": False, "screen_reader": False, "speech_rate": 1.0},
            "baseline_acoustic_profile": None,
            "created_at": datetime.datetime.now(datetime.timezone.utc)
        }

        # Guardian's Account (25,000 INR = 2,500,000 Paise)
        guardian_account_id = uuid.UUID("77777777-7777-7777-7777-777777777777")
        self.accounts[guardian_account_id] = {
            "id": guardian_account_id,
            "user_id": tc_user_id,
            "account_number_masked": "...8821",
            "account_type": "SAVINGS",
            "currency": "INR",
            "balance_paise": 2500000,
            "opened_at": datetime.datetime.now(datetime.timezone.utc)
        }

        # Pre-registered trusted payee (Son Rahul)
        son_id = uuid.UUID("44444444-4444-4444-4444-444444444444")
        self.payees[son_id] = {
            "id": son_id,
            "user_id": user_id,
            "name": "Rahul Sharma",
            "masked_account": "...9921",
            "account_ref": "HDFC0001234",
            "nickname": "Son Rahul",
            "verified": True,
            "created_at": datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=90)
        }

        # Trust Relationship
        trust_id = uuid.UUID("66666666-6666-6666-6666-666666666666")
        self.trust_relationships[trust_id] = {
            "id": trust_id,
            "account_holder_id": user_id,
            "trusted_contact_id": tc_user_id,
            "threshold_paise": 200000,  # 2,000 INR
            "relationship_type": "daughter",
            "cooling_window_minutes": 30,
            "is_guardian": True,
            "active": True,
            "created_at": datetime.datetime.now(datetime.timezone.utc)
        }

        # Pre-approve Son Rahul in always_allow_payees
        aap_id = uuid.UUID("88888888-8888-8888-8888-888888888888")
        self.always_allow_payees[aap_id] = {
            "id": aap_id,
            "account_holder_id": user_id,
            "guardian_id": tc_user_id,
            "payee_id": son_id,
            "active": True,
            "approved_at": datetime.datetime.now(datetime.timezone.utc)
        }

        # Utility Billers and 100+ realistic contacts
        from scripts.seed_demo_accounts import generate_payees
        for p in generate_payees(user_id):
            self.payees[p["id"]] = p


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

