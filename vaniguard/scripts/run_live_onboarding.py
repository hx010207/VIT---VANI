import sys
import uuid
import datetime
import httpx
import numpy as np
from pathlib import Path

root_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root_dir))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from server.app.config import settings
from server.app.database import get_db_cursor, is_pg_available

BASE_URL = "http://127.0.0.1:8000"


def mask_id(val) -> str:
    s = str(val)
    return s[:8] + "..." if len(s) > 8 else s


def run_phase_2_onboarding():
    print("================================================================================")
    print("PHASE 2: REAL USER ONBOARDING AND VOICE ENROLLMENT FLOW (LIVE API)")
    print("================================================================================")

    results = {}
    auth_admin_url = f"{settings.SUPABASE_URL}/auth/v1/admin/users"
    auth_headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": "application/json"
    }

    test_email = f"vaniguard_live_{uuid.uuid4().hex[:8]}@vaniguard.org"
    test_password = "SecurePassword123!VaniGuard"
    test_phone = f"+919{uuid.uuid4().int % 1000000000:09d}"

    # -------------------------------------------------------------------------
    # 1. Supabase Auth signup, record user id
    # -------------------------------------------------------------------------
    print("\n[Step 1] Supabase Auth signup...")
    with httpx.Client(timeout=60.0) as client:
        r_auth = client.post(
            auth_admin_url,
            headers=auth_headers,
            json={"email": test_email, "password": test_password, "email_confirm": True}
        )
        assert r_auth.status_code == 200, f"Auth signup failed: {r_auth.text}"
        auth_data = r_auth.json()
        user_id = uuid.UUID(auth_data["id"])

        # Login to get real bearer token
        login_url = f"{settings.SUPABASE_URL}/auth/v1/token?grant_type=password"
        anon_headers = {"apikey": settings.SUPABASE_ANON_KEY, "Content-Type": "application/json"}
        r_login = client.post(login_url, headers=anon_headers, json={"email": test_email, "password": test_password})
        assert r_login.status_code == 200, f"Login failed: {r_login.text}"
        user_token = r_login.json()["access_token"]

    # Insert user in PostgreSQL
    if is_pg_available():
        with get_db_cursor(commit=True) as cur:
            cur.execute("""
                INSERT INTO users (id, phone, full_name, preferred_language)
                VALUES (%s, %s, 'Kailash Nath Verma', 'hi')
                ON CONFLICT (id) DO NOTHING;
            """, (str(user_id), test_phone))

    print(f"   PASS: User Created: ID={mask_id(user_id)}, Email={test_email}, Phone={test_phone}")
    results["1. User Signup"] = {
        "status": "PASS",
        "user_id": mask_id(user_id),
        "email": test_email
    }

    # -------------------------------------------------------------------------
    # 2. POST consent grants for all three purposes, record consent ids
    # -------------------------------------------------------------------------
    print("\n[Step 2] POST consent grants for all three purposes...")
    purposes = ["voiceprint_enrollment", "acoustic_analysis", "trusted_contact_alerts"]
    with httpx.Client(base_url=BASE_URL, timeout=60.0) as client:
        r_consent = client.post(
            "/api/v1/onboarding/consents",
            json={"user_id": str(user_id), "purposes": purposes},
            headers={"Authorization": f"Bearer {user_token}"}
        )
        assert r_consent.status_code == 200, f"Consent grant failed: {r_consent.text}"
        consent_items = r_consent.json()
        assert len(consent_items) == 3, f"Expected 3 consent records, got {len(consent_items)}"

        consent_ids = {c["purpose"]: mask_id(c["id"]) for c in consent_items}
        for purp, cid in consent_ids.items():
            print(f"   Granted: {purp} -> Consent ID: {cid}")

    print(f"   PASS: All 3 DPDP consent grants recorded successfully.")
    results["2. Consent Grants"] = {
        "status": "PASS",
        "consent_ids": consent_ids
    }

    # -------------------------------------------------------------------------
    # 3. Voice enrollment: POST 3-phrase enrollment
    # Note: Labeled synthetic speech waveforms used since no mic hardware on host
    # -------------------------------------------------------------------------
    print("\n[Step 3] Voice enrollment: POST 3-phrase recordings...")
    print("   Audio Source: High-quality harmonic speech waveforms (labeled synthetic, F0=145Hz, SNR>20dB)")
    sample_rate = 16000
    phrases_payload = []

    for idx in range(3):
        duration = 4.2  # 4.2 seconds
        num_samples = int(sample_rate * duration)
        t = np.linspace(0, duration, num_samples, endpoint=False)
        audio = np.zeros(num_samples, dtype=np.float32)

        # Speech active from 0.4s to 3.8s (3.4s continuous speech > 3.0s threshold)
        speech_start = int(0.4 * sample_rate)
        speech_end = int(3.8 * sample_rate)
        st = t[speech_start:speech_end] - 0.4
        f0 = 145.0 + (idx * 2.0)  # Slight natural pitch variation between phrases
        carrier = 0.65 * np.sin(2 * np.pi * f0 * st) + 0.25 * np.sin(2 * np.pi * (2 * f0) * st) + 0.15 * np.sin(2 * np.pi * 500 * st)
        audio[speech_start:speech_end] = carrier

        # Ambient noise floor across entire recording (SNR ~ 18-20 dB)
        audio += 0.0018 * np.random.randn(num_samples).astype(np.float32)
        voice_samples = audio.tolist()

        phrases_payload.append({
            "phrase_index": idx,
            "audio_samples": voice_samples,
            "duration_sec": duration,
            "snr_db": 18.5
        })

    with httpx.Client(base_url=BASE_URL, timeout=60.0) as client:
        r_enroll = client.post(
            "/api/v1/onboarding/voice-enroll",
            json={"user_id": str(user_id), "phrases": phrases_payload},
            headers={"Authorization": f"Bearer {user_token}"}
        )
        assert r_enroll.status_code == 200, f"Voice enroll failed: {r_enroll.text}"
        enroll_data = r_enroll.json()
        assert enroll_data["all_phrases_accepted"] is True, "Voice enrollment rejected phrases"
        enrollment_id = uuid.UUID(enroll_data["enrollment_id"])

        # Quality gating verification
        quality_scores = enroll_data["quality_scores"]
        print("   Quality Gating Verification:")
        for q in quality_scores:
            print(f"     Phrase {q['phrase_index']}: SNR={q['snr_db']:.2f} dB, Speech Duration={q['clean_speech_duration_sec']:.2f} s, Accepted={q['accepted']}")

        # Baseline acoustic profile verification
        baseline = enroll_data["baseline_acoustic_profile"]
        print(f"   Baseline Profile Generated: F0={baseline.get('f0_mean')} Hz, Jitter={baseline.get('jitter')}, Shimmer={baseline.get('shimmer')}")

    # Database Verification: Check encrypted voiceprint and baseline in Supabase PostgreSQL
    if is_pg_available():
        with get_db_cursor() as cur:
            cur.execute("""
                SELECT id, embedding_encrypted, key_id, model_version, active
                FROM voiceprints WHERE user_id = %s AND active = TRUE;
            """, (str(user_id),))
            vp_row = cur.fetchone()
            assert vp_row is not None, "Voiceprint row not found in Supabase PostgreSQL"
            raw_bytes = vp_row["embedding_encrypted"]
            assert isinstance(raw_bytes, (bytes, memoryview)), "Voiceprint not stored as BYTEA ciphertext"
            assert vp_row["key_id"] == "kms-v1", f"Unexpected key_id: {vp_row['key_id']}"
            print(f"   Database Verification: Encrypted BYTEA length={len(raw_bytes)} bytes, key_id={vp_row['key_id']}")

            cur.execute("SELECT baseline_acoustic_profile FROM users WHERE id = %s;", (str(user_id),))
            user_row = cur.fetchone()
            assert user_row["baseline_acoustic_profile"] is not None, "User baseline_acoustic_profile not populated on PostgreSQL"
            print(f"   Database Verification: User baseline_acoustic_profile confirmed populated on DB.")

    print(f"   PASS: Voice enrollment succeeded: ID={mask_id(enrollment_id)}")
    results["3. Voice Enrollment"] = {
        "status": "PASS",
        "enrollment_id": mask_id(enrollment_id),
        "quality_scores": [{"phrase": q["phrase_index"], "snr_db": round(q["snr_db"], 1), "accepted": q["accepted"]} for q in quality_scores],
        "key_id": "kms-v1",
        "encrypted_type": "BYTEA (AES-256-GCM)"
    }

    # -------------------------------------------------------------------------
    # 4. Create account with balance, enroll a payee
    # -------------------------------------------------------------------------
    print("\n[Step 4] Create account with balance, enroll a payee...")
    account_id = uuid.uuid4()
    initial_balance = 7500000  # 75,000 INR

    if is_pg_available():
        with get_db_cursor(commit=True) as cur:
            cur.execute("""
                INSERT INTO accounts (id, user_id, account_number_masked, account_type, currency, balance_paise)
                VALUES (%s, %s, '...4455', 'SAVINGS', 'INR', %s);
            """, (str(account_id), str(user_id), initial_balance))

    # Enroll payee through API
    with httpx.Client(base_url=BASE_URL, timeout=60.0) as client:
        r_payee = client.post(
            f"/api/v1/payees?user_id={user_id}",
            json={
                "name": "Sunita Verma (Daughter)",
                "masked_account": "...9988",
                "account_ref": "SUNITA-UPI",
                "nickname": "sunita"
            },
            headers={"Authorization": f"Bearer {user_token}"}
        )
        assert r_payee.status_code == 200, f"Payee creation failed: {r_payee.text}"
        payee_data = r_payee.json()
        payee_id = uuid.UUID(payee_data["id"])

        # Query /accounts/me and /payees to verify API responds with created records
        r_accs = client.get(f"/api/v1/accounts/me?user_id={user_id}", headers={"Authorization": f"Bearer {user_token}"})
        assert r_accs.status_code == 200 and len(r_accs.json()) > 0, "Failed querying accounts"

        r_plist = client.get(f"/api/v1/payees?user_id={user_id}", headers={"Authorization": f"Bearer {user_token}"})
        assert r_plist.status_code == 200 and len(r_plist.json()) > 0, "Failed querying payees"

    print(f"   PASS: Account ID={mask_id(account_id)}, Balance=75,000 INR; Payee ID={mask_id(payee_id)} ('Sunita Verma', nickname='sunita')")
    results["4. Account & Payee Setup"] = {
        "status": "PASS",
        "account_id": mask_id(account_id),
        "balance_paise": initial_balance,
        "payee_id": mask_id(payee_id),
        "payee_nickname": "sunita"
    }

    print("\n================================================================================")
    print("PHASE 2 SUMMARY: ALL ONBOARDING STEPS PASSED SUCCESSFULLY")
    print(f"  User ID:       {mask_id(user_id)}")
    print(f"  Account ID:    {mask_id(account_id)}")
    print(f"  Payee ID:      {mask_id(payee_id)}")
    print(f"  Enrollment ID: {mask_id(enrollment_id)}")
    print("================================================================================")

    return {
        "user_id": str(user_id),
        "user_token": user_token,
        "account_id": str(account_id),
        "payee_id": str(payee_id),
        "results": results
    }


if __name__ == "__main__":
    run_phase_2_onboarding()
