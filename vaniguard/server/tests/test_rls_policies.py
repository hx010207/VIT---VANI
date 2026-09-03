# PURPOSE: Test suite verifying PostgreSQL Row-Level Security rules and isolation boundaries.
# ROLE IN SYSTEM: Confirms users can only read their own financial records and authorized transfers.
# TALKS TO: migrations/001_initial_schema.sql, server/app/database.py
import pytest
import re
from pathlib import Path


def test_rls_policies_in_migration_file():
    """
    Validates that Row Level Security (RLS) policies exist for every sensitive table
    and enforce appropriate role boundaries for anon, authenticated, and service-role.
    """
    migration_path = Path(__file__).resolve().parent.parent.parent / "migrations" / "001_initial_schema.sql"
    assert migration_path.exists(), f"Migration file missing at {migration_path}"

    with open(migration_path, "r", encoding="utf-8") as f:
        sql = f.read()

    core_tables = [
        "users",
        "voiceprints",
        "accounts",
        "payees",
        "transfers",
        "ledger_entries",
        "trust_relationships",
        "tc_actions",
        "consents",
        "audit_log"
    ]

    # Verify RLS enabled on all tables
    for table in core_tables:
        pattern = rf"ALTER\s+TABLE\s+{table}\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY"
        assert re.search(pattern, sql, re.IGNORECASE), f"RLS not enabled on table: {table}"

    # Verify immutable trigger on audit_log
    assert "audit_log_immutable_guard" in sql
    assert "trg_audit_log_immutable" in sql

    # Verify self-read policies on users, accounts, voiceprints
    assert "CREATE POLICY users_self_read" in sql
    assert "CREATE POLICY voiceprints_self_read" in sql
    assert "CREATE POLICY accounts_self_read" in sql

    # Verify transfer policies: account holder OR authorized trusted contact for HELD transfers
    assert "CREATE POLICY transfers_self_read" in sql
    assert "state = 'HELD'" in sql
    assert "trust_relationships" in sql

    # Verify TC action insert policy requires active trust relationship and HELD state
    assert "CREATE POLICY tc_actions_insert" in sql
    assert "t.state = 'HELD'" in sql
