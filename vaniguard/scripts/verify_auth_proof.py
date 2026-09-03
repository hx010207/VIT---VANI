import sys
import uuid
import datetime
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

import httpx
from fastapi.testclient import TestClient
from server.app.main import app
from server.app.config import settings
from server.app.database import get_db_cursor, is_pg_available, db

def verify_auth_proof():
    print("==================================================")
    print("VaniGuard FIX 3: Supabase JWT Auth Verification Proof")
    print("==================================================")

    # 1. Create a real user in Supabase Auth via Admin API
    test_email = f"vaniguard_auth_test_{uuid.uuid4().hex[:8]}@vaniguard.org"
    test_password = "SecurePassword123!Test"
    admin_url = f"{settings.SUPABASE_URL}/auth/v1/admin/users"
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": "application/json"
    }
    create_payload = {
        "email": test_email,
        "password": test_password,
        "email_confirm": True
    }

    user_id = None
    with httpx.Client() as client:
        r = client.post(admin_url, headers=headers, json=create_payload)
        assert r.status_code == 200, f"Failed to create test user: {r.text}"
        user_data = r.json()
        user_id = uuid.UUID(user_data["id"])
        print(f"[Step 1] Created real Supabase Auth user: ID={user_id}, Email={test_email}")

        # 2. Login via Supabase GoTrue to obtain real signed access token
        login_url = f"{settings.SUPABASE_URL}/auth/v1/token?grant_type=password"
        login_headers = {
            "apikey": settings.SUPABASE_ANON_KEY,
            "Content-Type": "application/json"
        }
        login_payload = {
            "email": test_email,
            "password": test_password
        }
        r_login = client.post(login_url, headers=login_headers, json=login_payload)
        assert r_login.status_code == 200, f"Login failed: {r_login.text}"
        valid_token = r_login.json()["access_token"]
        print(f"[Step 2] Obtained real Supabase Auth JWT (length={len(valid_token)})")

    # 3. Seed user, account, payee in DB
    source_acc_id = uuid.uuid4()
    payee_id = uuid.uuid4()
    if is_pg_available():
        with get_db_cursor(commit=True) as cur:
            cur.execute("""
                INSERT INTO users (id, phone, full_name, preferred_language)
                VALUES (%s, %s, 'Auth Verification User', 'en')
                ON CONFLICT (id) DO NOTHING;
            """, (str(user_id), f"+919{uuid.uuid4().int % 1000000000:09d}"))
            cur.execute("""
                INSERT INTO accounts (id, user_id, account_number_masked, account_type, currency, balance_paise)
                VALUES (%s, %s, '...9999', 'SAVINGS', 'INR', 1000000);
            """, (str(source_acc_id), str(user_id)))
            cur.execute("""
                INSERT INTO payees (id, user_id, name, masked_account, account_ref, verified)
                VALUES (%s, %s, 'Target Merchant', '...1234', 'REF-999', TRUE);
            """, (str(payee_id), str(user_id)))
    
    now_utc = datetime.datetime.now(datetime.timezone.utc)
    db.users[user_id] = {"id": user_id, "phone": "+919999999999", "full_name": "Auth User", "created_at": now_utc}
    db.accounts[source_acc_id] = {"id": source_acc_id, "user_id": user_id, "balance_paise": 1000000, "opened_at": now_utc}
    db.payees[payee_id] = {"id": payee_id, "user_id": user_id, "name": "Target Merchant", "created_at": now_utc}

    tc = TestClient(app)
    transfer_payload = {
        "source_account_id": str(source_acc_id),
        "payee_id": str(payee_id),
        "amount_paise": 50000
    }

    # Case A: Missing Token -> Expect 401
    print("\n[Step 3] Testing Request with NO Authorization header:")
    resp_no_token = tc.post(
        "/api/v1/transfers",
        json=transfer_payload,
        headers={"X-Idempotency-Key": str(uuid.uuid4())}
    )
    print(f"   HTTP Status: {resp_no_token.status_code}")
    print(f"   Response: {resp_no_token.json()}")
    assert resp_no_token.status_code == 401, f"Expected 401, got {resp_no_token.status_code}"

    # Case B: Invalid / Forged Token -> Expect 401
    print("\n[Step 4] Testing Request with INVALID / FORGED token:")
    resp_invalid_token = tc.post(
        "/api/v1/transfers",
        json=transfer_payload,
        headers={
            "X-Idempotency-Key": str(uuid.uuid4()),
            "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.forged.invalid"
        }
    )
    print(f"   HTTP Status: {resp_invalid_token.status_code}")
    print(f"   Response: {resp_invalid_token.json()}")
    assert resp_invalid_token.status_code == 401, f"Expected 401, got {resp_invalid_token.status_code}"

    # Case C: Valid Supabase-issued Token -> Expect 200 OK
    print("\n[Step 5] Testing Request with REAL Supabase Auth JWT token:")
    resp_valid_token = tc.post(
        "/api/v1/transfers",
        json=transfer_payload,
        headers={
            "X-Idempotency-Key": str(uuid.uuid4()),
            "Authorization": f"Bearer {valid_token}"
        }
    )
    print(f"   HTTP Status: {resp_valid_token.status_code}")
    print(f"   Response: {resp_valid_token.json()}")
    assert resp_valid_token.status_code == 200, f"Expected 200, got {resp_valid_token.status_code}"

    # Cleanup test user and data
    print("\n[Step 6] Cleaning up test data from live Supabase...")
    if is_pg_available():
        with get_db_cursor(commit=True) as cur:
            cur.execute("DELETE FROM ledger_entries WHERE account_id = %s;", (str(source_acc_id),))
            cur.execute("DELETE FROM transfers WHERE user_id = %s;", (str(user_id),))
            cur.execute("DELETE FROM accounts WHERE id = %s;", (str(source_acc_id),))
            cur.execute("DELETE FROM payees WHERE id = %s;", (str(payee_id),))
            cur.execute("DELETE FROM users WHERE id = %s;", (str(user_id),))
    
    with httpx.Client() as client:
        client.delete(f"{settings.SUPABASE_URL}/auth/v1/admin/users/{user_id}", headers=headers)
    
    print("Cleanup completed successfully.")
    print("\nSUCCESS: FIX 3 PROOF VERIFIED — 401 for missing/invalid tokens, 200 for valid Supabase JWT.")
    print("==================================================")

if __name__ == "__main__":
    verify_auth_proof()
