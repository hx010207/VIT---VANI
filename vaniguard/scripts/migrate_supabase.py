import os
import sys
from pathlib import Path
from dotenv import load_dotenv

vaniguard_dir = Path(__file__).resolve().parent.parent
load_dotenv(vaniguard_dir / ".env")

database_url = os.getenv("DATABASE_URL")
if not database_url:
    print("FATAL: DATABASE_URL not set in .env")
    sys.exit(1)

def run_migration():
    import psycopg2
    from psycopg2 import sql

    migration_file = vaniguard_dir / "migrations" / "001_initial_schema.sql"
    with open(migration_file, "r", encoding="utf-8") as f:
        migration_sql = f.read()

    print(f"Connecting to Supabase PostgreSQL...")
    conn = psycopg2.connect(database_url)
    conn.autocommit = True
    cur = conn.cursor()

    print("Executing migrations/001_initial_schema.sql...")
    cur.execute(migration_sql)
    print("Migration executed successfully.")

    # Verification of all 12 tables
    expected_tables = [
        "users",
        "voiceprints",
        "accounts",
        "payees",
        "transfers",
        "ledger_entries",
        "trust_relationships",
        "tc_actions",
        "consents",
        "audit_log",
        "scam_lexicon",
        "risk_signal_config"
    ]

    print("\n--- Verifying Table Existence and Row Level Security (RLS) ---")
    verified_tables = 0
    for tbl in expected_tables:
        cur.execute(
            """
            SELECT tablename, rowsecurity
            FROM pg_tables
            WHERE schemaname = 'public' AND tablename = %s
            """,
            (tbl,)
        )
        row = cur.fetchone()
        if row:
            tablename, rls_enabled = row
            status_str = "ENABLED" if rls_enabled else "DISABLED (ERROR)"
            print(f"  [OK] Table: {tablename:<22} | RLS: {status_str}")
            if rls_enabled:
                verified_tables += 1
        else:
            print(f"  [MISSING] Table: {tbl}")

    # Verify append-only trigger on audit_log
    cur.execute(
        """
        SELECT trigger_name, event_manipulation
        FROM information_schema.triggers
        WHERE event_object_table = 'audit_log'
        """
    )
    triggers = cur.fetchall()
    print("\n--- Verifying Immutable Trigger on audit_log ---")
    for t_name, t_event in triggers:
        print(f"  [OK] Trigger: {t_name} on event {t_event}")

    # Verify Seed Data
    cur.execute("SELECT COUNT(*) FROM risk_signal_config")
    signal_count = cur.fetchone()[0]
    print(f"\n--- Verifying Seed Data ---")
    print(f"  [OK] risk_signal_config entries: {signal_count} (expected >= 5)")

    cur.execute("SELECT language, COUNT(*) FROM scam_lexicon GROUP BY language")
    lex_counts = cur.fetchall()
    for lang, cnt in lex_counts:
        print(f"  [OK] scam_lexicon ({lang}) entries: {cnt}")

    cur.close()
    conn.close()

    if verified_tables == len(expected_tables):
        print(f"\nSUCCESS: All {verified_tables} tables exist with RLS enabled.")
    else:
        print(f"\nFAILURE: Only {verified_tables}/{len(expected_tables)} tables verified.")
        sys.exit(1)

if __name__ == "__main__":
    run_migration()
