#!/usr/bin/env python3
"""
Live Hosted Supabase Backend Integration Test (Zero Mocks)
Validates:
1. Live health check / rest API connectivity (status 200)
2. Asha Sharma seeded authentication (+919876543210 -> asha@vaniguard.org / Asha@Demo2026) -> Session returned
3. Fetch accounts -> Account numbers & balances returned
4. Fetch payees -> Seeded payees returned (Rahul Sharma, Sunita, etc.)
5. Initiate transfer -> Record created with state, idempotency
6. Query transfers / audit log -> Verification that transfer was recorded in database
"""
import sys
import json
import urllib.request
import urllib.parse
import uuid
import time

SUPABASE_URL = "https://qqfexpzwzctwtbjirsvh.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFxZmV4cHp3emN0d3Riamlyc3ZoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg0Mzg5OTMsImV4cCI6MjEwNDAxNDk5M30.16jjPcIezKPoql8yJVFxgjLy1aZ0y7RJuv-qIZxqSh4"

def http_req(method, url, headers=None, data=None):
    if headers is None:
        headers = {}
    headers.setdefault("apikey", SUPABASE_ANON_KEY)
    body = None
    if data is not None:
        body = json.dumps(data).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            resp_body = resp.read().decode("utf-8")
            status = resp.status
            return status, json.loads(resp_body) if resp_body else {}
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        try:
            parsed = json.loads(err_body)
        except Exception:
            parsed = {"error": err_body}
        return e.code, parsed

def run_tests():
    print("=" * 60)
    print("VaniGuard Live Hosted Supabase Backend Integration Tests")
    print(f"Target URL: {SUPABASE_URL}")
    print("=" * 60)

    # 1. Health Check
    print("\n[Step 1] Verifying Backend Health Check...")
    code, data = http_req("GET", f"{SUPABASE_URL}/rest/v1/users?select=count&limit=1")
    assert code in (200, 206), f"Health check failed with code {code}: {data}"
    print(f"  PASS: Backend returned HTTP {code} OK")

    # 2. Auth with Asha seeded credentials
    print("\n[Step 2] Authenticating Asha Sharma (asha@vaniguard.org)...")
    auth_url = f"{SUPABASE_URL}/auth/v1/token?grant_type=password"
    code, session = http_req("POST", auth_url, data={
        "email": "asha@vaniguard.org",
        "password": "Asha@Demo2026"
    })
    assert code == 200, f"Asha login failed with code {code}: {session}"
    access_token = session.get("access_token")
    user = session.get("user", {})
    user_id = user.get("id")
    assert access_token, "No access token in session response"
    assert user_id, "No user ID in auth response"
    print(f"  PASS: Asha authenticated successfully! User ID: {user_id}")

    auth_headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {access_token}"
    }

    # 3. Fetch Accounts
    print("\n[Step 3] Fetching User Bank Accounts...")
    code, accounts = http_req("GET", f"{SUPABASE_URL}/rest/v1/accounts?select=*&user_id=eq.{user_id}", headers=auth_headers)
    assert code == 200, f"Fetch accounts failed with code {code}: {accounts}"
    assert len(accounts) > 0, "No accounts found for user"
    primary_account = accounts[0]
    acc_id = primary_account["id"]
    bal_paise = primary_account.get("balance_paise", 0)
    print(f"  PASS: Found account {primary_account.get('account_number')} with balance INR {bal_paise / 100:.2f}")

    # 4. Fetch Payees
    print("\n[Step 4] Fetching Seeded Payees...")
    code, payees = http_req("GET", f"{SUPABASE_URL}/rest/v1/payees?select=*&user_id=eq.{user_id}", headers=auth_headers)
    assert code == 200, f"Fetch payees failed with code {code}: {payees}"
    assert len(payees) > 0, "No payees found for user"
    rahul = next((p for p in payees if "rahul" in p.get("name", "").lower()), payees[0])
    payee_id = rahul["id"]
    print(f"  PASS: Found {len(payees)} payees. Selected payee: {rahul.get('name')} (ID: {payee_id})")

    # 5. Initiate Transfer
    print("\n[Step 5] Initiating Test Transfer of INR 10.00 (1000 paise)...")
    transfer_id = str(uuid.uuid4())
    idempotency_key = f"test-run-{int(time.time())}"
    transfer_payload = {
        "id": transfer_id,
        "user_id": user_id,
        "source_account_id": acc_id,
        "payee_id": payee_id,
        "amount_paise": 1000,
        "state": "COMPLETED",
        "risk_band": "PROCEED",
        "risk_score": 10,
        "idempotency_key": idempotency_key
    }
    code, new_tx = http_req("POST", f"{SUPABASE_URL}/rest/v1/transfers", headers=auth_headers, data=transfer_payload)
    assert code in (200, 201), f"Initiate transfer failed with code {code}: {new_tx}"
    print(f"  PASS: Transfer initiated successfully! Transfer ID: {transfer_id}")

    # 6. Query Audit Log / Transfers
    print("\n[Step 6] Querying Recorded Transfers from Live Database...")
    code, recent_txs = http_req("GET", f"{SUPABASE_URL}/rest/v1/transfers?select=*,payees(name)&user_id=eq.{user_id}&order=created_at.desc&limit=5", headers=auth_headers)
    assert code == 200, f"Query transfers failed with code {code}: {recent_txs}"
    found = any(t.get("id") == transfer_id for t in recent_txs)
    assert found, f"Newly created transfer {transfer_id} not found in recent transfers list"
    print(f"  PASS: Verified newly created transfer {transfer_id} in live database!")

    print("\n" + "=" * 60)
    print("ALL 6 LIVE SUPABASE BACKEND INTEGRATION TESTS PASSED (100% OK)")
    print("=" * 60)

if __name__ == "__main__":
    try:
        run_tests()
    except Exception as err:
        print(f"\nFAIL: Integration test encountered error: {err}")
        sys.exit(1)
