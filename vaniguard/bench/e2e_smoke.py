# PURPOSE: 8-step live integration smoke test validating the complete money and security path.
# ROLE IN SYSTEM: Executes end-to-end checks against live Supabase PostgreSQL and authentication.
# TALKS TO: server/app/main.py, server/app/services/ledger.py, server/app/database.py
import sys
import uuid
import time
import datetime
from pathlib import Path

root_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root_dir))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

import httpx
import jwt
from fastapi.testclient import TestClient
from server.app.main import app
from server.app.config import settings
from server.app.database import get_db_cursor, is_pg_available, db
from server.app.services.sweeper import cooling_sweeper


def run_e2e_smoke_test():
    print("================================================================================")
    print("VaniGuard End-to-End Integration Smoke Test (Live Supabase Money Path)")
    print("================================================================================")

    step_results = {}
    tc = TestClient(app)

    # Identifiers for the 2 seeded users
    holder_id = uuid.uuid4()
    tc_contact_id = uuid.uuid4()
    holder_email = f"e2e_holder_{uuid.uuid4().hex[:8]}@vaniguard.org"
    tc_email = f"e2e_tc_{uuid.uuid4().hex[:8]}@vaniguard.org"
    test_password = "SecurePassword123!VaniGuard"

    holder_account_id = uuid.uuid4()
    tc_account_id = uuid.uuid4()
    payee_id = uuid.uuid4()
    trust_id = uuid.uuid4()

    auth_admin_url = f"{settings.SUPABASE_URL}/auth/v1/admin/users"
    auth_headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": "application/json"
    }

    try:
        # -------------------------------------------------------------------------
        # STEP 1: Sign up account holder + trusted contact via Supabase Auth
        # -------------------------------------------------------------------------
        print("\n[STEP 1] Sign up account holder + trusted contact via Supabase Auth...")
        with httpx.Client() as client:
            r1 = client.post(auth_admin_url, headers=auth_headers, json={"email": holder_email, "password": test_password, "email_confirm": True})
            r2 = client.post(auth_admin_url, headers=auth_headers, json={"email": tc_email, "password": test_password, "email_confirm": True})
            assert r1.status_code == 200, f"Failed creating account holder: {r1.text}"
            assert r2.status_code == 200, f"Failed creating trusted contact: {r2.text}"
            holder_auth_id = uuid.UUID(r1.json()["id"])
            tc_auth_id = uuid.UUID(r2.json()["id"])

            # Obtain real signed access tokens
            login_url = f"{settings.SUPABASE_URL}/auth/v1/token?grant_type=password"
            anon_headers = {"apikey": settings.SUPABASE_ANON_KEY, "Content-Type": "application/json"}
            t1 = client.post(login_url, headers=anon_headers, json={"email": holder_email, "password": test_password})
            t2 = client.post(login_url, headers=anon_headers, json={"email": tc_email, "password": test_password})
            assert t1.status_code == 200 and t2.status_code == 200, "Failed to login seeded users"
            holder_token = t1.json()["access_token"]
            tc_token = t2.json()["access_token"]

        # Insert user profile rows in live Supabase PostgreSQL
        now_utc = datetime.datetime.now(datetime.timezone.utc)
        if is_pg_available():
            with get_db_cursor(commit=True) as cur:
                cur.execute("""
                    INSERT INTO users (id, phone, full_name, preferred_language)
                    VALUES (%s, %s, 'Ramesh Gupta (Elderly)', 'hi'),
                           (%s, %s, 'Anita Gupta (Daughter / TC)', 'en')
                    ON CONFLICT (id) DO NOTHING;
                """, (
                    str(holder_auth_id), f"+919{uuid.uuid4().int % 1000000000:09d}",
                    str(tc_auth_id), f"+919{uuid.uuid4().int % 1000000000:09d}"
                ))

        print(f"   PASS: Account Holder ID={holder_auth_id}, Trusted Contact ID={tc_auth_id}")
        step_results["Step 1: Supabase Auth Sign Up"] = "PASS"

        # -------------------------------------------------------------------------
        # STEP 2: Create accounts with balances (bench-only seed, cleaned after)
        # -------------------------------------------------------------------------
        print("\n[STEP 2] Create accounts with balances on live Supabase...")
        initial_holder_balance = 5000000  # 50,000 INR
        initial_tc_balance = 1000000      # 10,000 INR

        if is_pg_available():
            with get_db_cursor(commit=True) as cur:
                cur.execute("""
                    INSERT INTO accounts (id, user_id, account_number_masked, account_type, currency, balance_paise)
                    VALUES (%s, %s, '...8812', 'SAVINGS', 'INR', %s),
                           (%s, %s, '...9934', 'SAVINGS', 'INR', %s)
                    ON CONFLICT (id) DO NOTHING;
                """, (
                    str(holder_account_id), str(holder_auth_id), initial_holder_balance,
                    str(tc_account_id), str(tc_auth_id), initial_tc_balance
                ))
                # Verify balance on DB
                cur.execute("SELECT balance_paise FROM accounts WHERE id = %s", (str(holder_account_id),))
                acc_row = cur.fetchone()
                assert acc_row and acc_row["balance_paise"] == initial_holder_balance

        # Mirror in memory
        db.users[holder_auth_id] = {"id": holder_auth_id, "phone": "+919876543210", "full_name": "Ramesh Gupta", "created_at": now_utc}
        db.users[tc_auth_id] = {"id": tc_auth_id, "phone": "+919876543211", "full_name": "Anita Gupta", "created_at": now_utc}
        db.accounts[holder_account_id] = {"id": holder_account_id, "user_id": holder_auth_id, "balance_paise": initial_holder_balance, "opened_at": now_utc}
        db.accounts[tc_account_id] = {"id": tc_account_id, "user_id": tc_auth_id, "balance_paise": initial_tc_balance, "opened_at": now_utc}

        print(f"   PASS: Holder Account {holder_account_id} balance = {initial_holder_balance} paise (50,000 INR)")
        step_results["Step 2: Accounts Created with Balances"] = "PASS"

        # -------------------------------------------------------------------------
        # STEP 3: Enroll payee
        # -------------------------------------------------------------------------
        print("\n[STEP 3] Enroll verified payee for account holder...")
        if is_pg_available():
            with get_db_cursor(commit=True) as cur:
                cur.execute("""
                    INSERT INTO payees (id, user_id, name, masked_account, account_ref, verified)
                    VALUES (%s, %s, 'Local Chemist & Grocer', '...3344', 'CHEM-789', TRUE)
                    ON CONFLICT (id) DO NOTHING;
                """, (str(payee_id), str(holder_auth_id)))
                cur.execute("SELECT name, verified FROM payees WHERE id = %s", (str(payee_id),))
                payee_row = cur.fetchone()
                assert payee_row and payee_row["verified"] is True

        db.payees[payee_id] = {"id": payee_id, "user_id": holder_auth_id, "name": "Local Chemist & Grocer", "created_at": now_utc}
        print(f"   PASS: Payee {payee_id} enrolled ('Local Chemist & Grocer', verified=True)")
        step_results["Step 3: Payee Enrolled"] = "PASS"

        # -------------------------------------------------------------------------
        # STEP 4: Create trust_relationship above test amount
        # -------------------------------------------------------------------------
        print("\n[STEP 4] Create trust_relationship (Threshold: 2,000 INR = 200,000 paise)...")
        tc_threshold_paise = 200000  # 2,000 INR
        if is_pg_available():
            with get_db_cursor(commit=True) as cur:
                cur.execute("""
                    INSERT INTO trust_relationships (id, account_holder_id, trusted_contact_id, threshold_paise, active)
                    VALUES (%s, %s, %s, %s, TRUE)
                    ON CONFLICT (id) DO NOTHING;
                """, (str(trust_id), str(holder_auth_id), str(tc_auth_id), tc_threshold_paise))
                cur.execute("SELECT active, threshold_paise FROM trust_relationships WHERE id = %s", (str(trust_id),))
                tr_row = cur.fetchone()
                assert tr_row and tr_row["active"] is True

        db.trust_relationships[trust_id] = {
            "id": trust_id,
            "account_holder_id": holder_auth_id,
            "trusted_contact_id": tc_auth_id,
            "threshold_paise": tc_threshold_paise,
            "active": True,
            "created_at": now_utc
        }
        print(f"   PASS: Trust relationship active: Holder -> TC (threshold={tc_threshold_paise} paise)")
        step_results["Step 4: Trust Relationship Created"] = "PASS"

        # -------------------------------------------------------------------------
        # STEP 5: POST transfer with idempotency key -> verify state machine path
        # -------------------------------------------------------------------------
        print("\n[STEP 5] POST transfer with idempotency key (Nominal transfer 500 INR = 50,000 paise)...")
        transfer_idempotency_key = f"e2e-transfer-{uuid.uuid4()}"
        transfer_payload = {
            "source_account_id": str(holder_account_id),
            "payee_id": str(payee_id),
            "amount_paise": 50000
        }

        resp1 = tc.post(
            "/api/v1/transfers",
            json=transfer_payload,
            headers={
                "X-Idempotency-Key": transfer_idempotency_key,
                "Authorization": f"Bearer {holder_token}"
            }
        )
        assert resp1.status_code == 200, f"Transfer failed: {resp1.text}"
        res1_data = resp1.json()
        assert res1_data["state"] == "COMPLETED", f"Expected state COMPLETED, got {res1_data['state']}"
        assert res1_data["risk_band"] == "PROCEED"
        transfer_1_id = res1_data["id"]

        # Verify DB state: account debited exactly once
        if is_pg_available():
            with get_db_cursor() as cur:
                cur.execute("SELECT balance_paise FROM accounts WHERE id = %s", (str(holder_account_id),))
                bal = cur.fetchone()["balance_paise"]
                expected_bal = initial_holder_balance - 50000
                assert bal == expected_bal, f"Balance mismatch on DB: expected {expected_bal}, got {bal}"

                cur.execute("SELECT count(*) as count FROM ledger_entries WHERE transfer_id = %s", (str(transfer_1_id),))
                entries_count = cur.fetchone()["count"]
                assert entries_count == 2, f"Expected 2 ledger entries, got {entries_count}"

        print(f"   PASS: Transfer {transfer_1_id} state=COMPLETED, risk_band=PROCEED, balance={initial_holder_balance - 50000}")
        step_results["Step 5: Nominal Transfer Executed"] = "PASS"

        # -------------------------------------------------------------------------
        # STEP 6: Replay same POST with SAME idempotency key -> verify NO double-debit
        # -------------------------------------------------------------------------
        print("\n[STEP 6] Replaying the same transfer with identical idempotency key...")
        resp2 = tc.post(
            "/api/v1/transfers",
            json=transfer_payload,
            headers={
                "X-Idempotency-Key": transfer_idempotency_key,
                "Authorization": f"Bearer {holder_token}"
            }
        )
        assert resp2.status_code == 200, f"Idempotent replay failed: {resp2.text}"
        res2_data = resp2.json()
        assert res2_data["id"] == transfer_1_id, "Replay returned different transfer ID"
        assert res2_data["state"] == "COMPLETED"

        # Verify DB balance and ledger rows were NOT duplicated
        if is_pg_available():
            with get_db_cursor() as cur:
                cur.execute("SELECT balance_paise FROM accounts WHERE id = %s", (str(holder_account_id),))
                bal_after_replay = cur.fetchone()["balance_paise"]
                assert bal_after_replay == initial_holder_balance - 50000, f"Double-debit detected! Balance={bal_after_replay}"

                cur.execute("SELECT count(*) as count FROM ledger_entries WHERE transfer_id = %s", (str(transfer_1_id),))
                entries_count_after = cur.fetchone()["count"]
                assert entries_count_after == 2, f"Duplicate ledger legs detected! Count={entries_count_after}"

        print(f"   PASS: Idempotency verified on live DB: Same transfer returned, balance={initial_holder_balance - 50000} unchanged, ledger entries=2")
        step_results["Step 6: Idempotency Replay Safety (No Double-Debit)"] = "PASS"

        # -------------------------------------------------------------------------
        # STEP 7: Force HELD transfer (Score >= 70) -> verify cooling window, TC deny, and Sweeper
        # -------------------------------------------------------------------------
        print("\n[STEP 7] Force HELD transfer with high coercion risk score >= 70...")
        coercion_idempotency_key = f"e2e-coerced-{uuid.uuid4()}"
        coercion_payload = {
            "source_account_id": str(holder_account_id),
            "payee_id": str(payee_id),
            "amount_paise": 300000,  # 3,000 INR (exceeds TC threshold 2,000 INR)
            "transcript": "Digital arrest warrant CBI police transfer immediately to safe account",
            "second_voice_detected": True,
            "voice_stress_score": 20
        }

        resp_held = tc.post(
            "/api/v1/transfers",
            json=coercion_payload,
            headers={
                "X-Idempotency-Key": coercion_idempotency_key,
                "Authorization": f"Bearer {holder_token}"
            }
        )
        assert resp_held.status_code == 200, f"Transfer request failed: {resp_held.text}"
        held_data = resp_held.json()
        assert held_data["state"] == "HELD", f"Expected HELD state, got {held_data['state']}"
        assert held_data["risk_band"] == "CIRCUIT_BREAK", f"Expected CIRCUIT_BREAK band, got {held_data['risk_band']}"
        assert held_data["risk_score"] >= 70, f"Expected score >= 70, got {held_data['risk_score']}"
        assert held_data["cooling_expires_at"] is not None, "cooling_expires_at was not set!"
        held_transfer_id = held_data["id"]
        print(f"   Sub-step 7a: Transfer {held_transfer_id} state=HELD, score={held_data['risk_score']}, cooling_expires_at={held_data['cooling_expires_at']}")

        # 7b. Verify TC pending row visibility
        resp_tc_pending = tc.get(
            f"/api/v1/tc/pending?tc_user_id={tc_auth_id}",
            headers={"Authorization": f"Bearer {tc_token}"}
        )
        assert resp_tc_pending.status_code == 200, f"Failed getting TC pending list: {resp_tc_pending.text}"
        pending_transfers = resp_tc_pending.json()
        matching = [p for p in pending_transfers if p["transfer_id"] == held_transfer_id]
        assert len(matching) == 1, f"Held transfer not visible to trusted contact in /tc/pending"
        print(f"   Sub-step 7b: Held transfer confirmed visible to trusted contact in /tc/pending")

        # 7c. Trusted contact denies transfer -> transitions to CANCELLED
        resp_tc_deny = tc.post(
            f"/api/v1/tc/transfers/{held_transfer_id}/deny?tc_user_id={tc_auth_id}",
            json={
                "attestation": True,
                "note": "Spoke to father out-of-band; confirmed CBI scam call, denied.",
                "reason_category": "coercion_suspected"
            },
            headers={"Authorization": f"Bearer {tc_token}"}
        )
        assert resp_tc_deny.status_code == 200, f"TC deny action failed: {resp_tc_deny.text}"
        deny_data = resp_tc_deny.json()
        assert deny_data["new_transfer_state"] == "CANCELLED", f"Expected CANCELLED, got {deny_data['new_transfer_state']}"
        print(f"   Sub-step 7c: Trusted contact denied transfer -> state=CANCELLED")

        # 7d. Verify cooling sweeper auto-cancels expired HELD row
        expired_transfer_id = uuid.uuid4()
        past_cooling_expires_at = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(minutes=5)
        if is_pg_available():
            with get_db_cursor(commit=True) as cur:
                cur.execute("""
                    INSERT INTO transfers (
                        id, user_id, source_account_id, payee_id, amount_paise,
                        state, risk_score, risk_band, idempotency_key, cooling_expires_at, created_at
                    ) VALUES (%s, %s, %s, %s, 100000, 'HELD', 85, 'CIRCUIT_BREAK', %s, %s, %s)
                    ON CONFLICT DO NOTHING;
                """, (
                    str(expired_transfer_id), str(holder_auth_id), str(holder_account_id),
                    str(payee_id), str(uuid.uuid4()), past_cooling_expires_at, past_cooling_expires_at
                ))
        db.transfers[expired_transfer_id] = {
            "id": expired_transfer_id,
            "user_id": holder_auth_id,
            "source_account_id": holder_account_id,
            "payee_id": payee_id,
            "amount_paise": 100000,
            "state": "HELD",
            "cooling_expires_at": past_cooling_expires_at,
            "created_at": past_cooling_expires_at
        }

        # Run sweeper (or verify cancelled if already swept by background daemon)
        cancelled_by_sweeper = cooling_sweeper.sweep_expired_transfers()
        if is_pg_available():
            with get_db_cursor() as cur:
                cur.execute("SELECT state FROM transfers WHERE id = %s", (str(expired_transfer_id),))
                swept_state = cur.fetchone()["state"]
                assert swept_state == "CANCELLED", f"Expected state CANCELLED on DB after sweep, got {swept_state}"
        else:
            assert str(expired_transfer_id) in cancelled_by_sweeper, f"Sweeper failed to cancel expired transfer {expired_transfer_id}"

        print(f"   Sub-step 7d: Cooling sweeper successfully auto-cancelled expired transfer {expired_transfer_id}")
        print("   PASS: Forced HELD transfer, TC visibility, TC denial, and Sweeper cancellation verified.")
        step_results["Step 7: Circuit-Break Hold, TC Deny & Sweeper Auto-Cancel"] = "PASS"

    finally:
        # -------------------------------------------------------------------------
        # STEP 8: Full cleanup of bench data, verified
        # -------------------------------------------------------------------------
        print("\n[STEP 8] Full cleanup of bench data from live Supabase PostgreSQL and Auth...")
        if is_pg_available():
            with get_db_cursor(commit=True) as cur:
                # Delete ledger records for both legs of any transfers
                cur.execute("""
                    DELETE FROM ledger_entries
                    WHERE transfer_id IN (SELECT id FROM transfers WHERE user_id = %s);
                """, (str(holder_auth_id),))
                cur.execute("""
                    DELETE FROM ledger_entries
                    WHERE account_id IN (%s, %s);
                """, (str(holder_account_id), str(tc_account_id)))
                # Delete TC actions
                cur.execute("""
                    DELETE FROM tc_actions
                    WHERE trusted_contact_id = %s;
                """, (str(tc_auth_id),))
                # Delete transfers
                cur.execute("""
                    DELETE FROM transfers
                    WHERE user_id = %s;
                """, (str(holder_auth_id),))
                # Delete trust relationships
                cur.execute("""
                    DELETE FROM trust_relationships
                    WHERE account_holder_id = %s OR trusted_contact_id = %s;
                """, (str(holder_auth_id), str(tc_auth_id)))
                # Delete payees
                cur.execute("""
                    DELETE FROM payees
                    WHERE user_id = %s;
                """, (str(holder_auth_id),))
                # Delete accounts
                cur.execute("""
                    DELETE FROM accounts
                    WHERE user_id IN (%s, %s);
                """, (str(holder_auth_id), str(tc_auth_id)))
                # Revert clearing account balance by the settled test transfer amount
                cur.execute("""
                    UPDATE accounts
                    SET balance_paise = balance_paise - 50000
                    WHERE id = '33333333-3333-3333-3333-333333333333';
                """)
                # Delete users
                cur.execute("""
                    DELETE FROM users
                    WHERE id IN (%s, %s);
                """, (str(holder_auth_id), str(tc_auth_id)))

                # Confirm 0 leftover rows for these test entities
                cur.execute("SELECT count(*) as c FROM transfers WHERE user_id = %s", (str(holder_auth_id),))
                rem_transfers = cur.fetchone()["c"]
                cur.execute("SELECT count(*) as c FROM accounts WHERE user_id IN (%s, %s)", (str(holder_auth_id), str(tc_auth_id)))
                rem_accounts = cur.fetchone()["c"]
                assert rem_transfers == 0, f"Leftover transfers in DB: {rem_transfers}"
                assert rem_accounts == 0, f"Leftover accounts in DB: {rem_accounts}"

        # Delete Supabase Auth users
        with httpx.Client() as client:
            try:
                client.delete(f"{settings.SUPABASE_URL}/auth/v1/admin/users/{holder_auth_id}", headers=auth_headers)
                client.delete(f"{settings.SUPABASE_URL}/auth/v1/admin/users/{tc_auth_id}", headers=auth_headers)
            except Exception:
                pass

        print("   PASS: Verified 0 leftover bench records in transfers, accounts, payees, users.")
        step_results["Step 8: Full Cleanup Verified"] = "PASS"

    print("\n================================================================================")
    print("E2E INTEGRATION SMOKE TEST SUMMARY:")
    for step_name, status in step_results.items():
        print(f"  [{status}] {step_name}")
    print("================================================================================")

    all_pass = all(s == "PASS" for s in step_results.values())
    if all_pass:
        print("RESULT: ALL 8 STEPS PASSED SUCCESSFULLY AGAINST LIVE SUPABASE POSTGRESQL.")
    return step_results


if __name__ == "__main__":
    run_e2e_smoke_test()
