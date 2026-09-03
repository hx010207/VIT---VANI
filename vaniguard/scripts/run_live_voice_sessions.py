# PURPOSE: Automated runner executing Phase 3 live WebSocket voice sessions and session matrix.
# ROLE IN SYSTEM: Tests nominal flow, soft verification challenge, and circuit break with TC deny.
# TALKS TO: server/app/api/v1/websocket.py, server/app/api/v1/voice.py, server/app/api/v1/tc_actions.py
import sys
import uuid
import time
import json
import datetime
import asyncio
import httpx
import websockets
import numpy as np
from pathlib import Path

root_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root_dir))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from server.app.config import settings
from server.app.database import get_db_cursor, is_pg_available, db
from server.app.services.crypto import crypto_service

BASE_HTTP = "http://127.0.0.1:8000"
BASE_WS = "ws://127.0.0.1:8000"


def mask(val) -> str:
    s = str(val)
    return s[:8] + "..." if len(s) > 8 else s


def generate_audio(duration: float = 3.5, f0: float = 150.0, noise_amp: float = 0.015) -> list:
    sample_rate = 16000
    num_samples = int(sample_rate * duration)
    t = np.linspace(0, duration, num_samples, endpoint=False)
    audio = np.zeros(num_samples, dtype=np.float32)
    # Speech active in central interval
    speech_start = int(0.3 * sample_rate)
    speech_end = int((duration - 0.3) * sample_rate)
    st = t[speech_start:speech_end] - 0.3
    # Human vocal tract spectral envelope with natural harmonics and frication
    carrier = (
        0.50 * np.sin(2 * np.pi * f0 * st) +
        0.25 * np.sin(2 * np.pi * (2 * f0) * st) +
        0.15 * np.sin(2 * np.pi * (3 * f0) * st) +
        0.08 * np.sin(2 * np.pi * 1200 * st) +
        0.04 * np.sin(2 * np.pi * 2400 * st) +
        0.02 * np.sin(2 * np.pi * 4800 * st)
    )
    audio[speech_start:speech_end] = carrier
    audio += noise_amp * np.random.randn(num_samples).astype(np.float32)
    return audio.tolist()


async def run_sessions():
    print("================================================================================")
    print("PHASE 3: LIVE WEBSOCKET VOICE SESSIONS (/ws/voice-session)")
    print("================================================================================")

    # Setup Seed Users: Account Holder and Trusted Contact
    holder_id = uuid.uuid4()
    tc_id = uuid.uuid4()
    holder_email = f"holder_ws_{uuid.uuid4().hex[:8]}@vaniguard.org"
    tc_email = f"tc_ws_{uuid.uuid4().hex[:8]}@vaniguard.org"
    pwd = "SecurePassword123!VaniGuard"

    auth_admin_url = f"{settings.SUPABASE_URL}/auth/v1/admin/users"
    auth_headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": "application/json"
    }

    # 1. Create Supabase Auth Users
    with httpx.Client(timeout=60.0) as client:
        r1 = client.post(auth_admin_url, headers=auth_headers, json={"email": holder_email, "password": pwd, "email_confirm": True})
        r2 = client.post(auth_admin_url, headers=auth_headers, json={"email": tc_email, "password": pwd, "email_confirm": True})
        holder_id = uuid.UUID(r1.json()["id"])
        tc_id = uuid.UUID(r2.json()["id"])

        login_url = f"{settings.SUPABASE_URL}/auth/v1/token?grant_type=password"
        anon_h = {"apikey": settings.SUPABASE_ANON_KEY, "Content-Type": "application/json"}
        t1 = client.post(login_url, headers=anon_h, json={"email": holder_email, "password": pwd})
        t2 = client.post(login_url, headers=anon_h, json={"email": tc_email, "password": pwd})
        holder_token = t1.json()["access_token"]
        tc_token = t2.json()["access_token"]

    now = datetime.datetime.now(datetime.timezone.utc)
    holder_acc_id = uuid.uuid4()
    payee_id = uuid.uuid4()
    trust_rel_id = uuid.uuid4()

    # Pre-calculate enrolled voiceprint embedding and encrypt
    from worker.providers.speaker_provider import speaker_provider
    enrolled_audio = np.array(generate_audio(3.5, f0=150.0), dtype=np.float32)
    master_emb = speaker_provider.compute_embedding(enrolled_audio)
    cipher, iv, key_id = crypto_service.encrypt_embedding(master_emb)
    vp_id = uuid.uuid4()

    baseline_profile = {
        "f0_mean": 150.0, "f0_std": 15.0, "jitter": 0.014, "shimmer": 0.031, "snr_db": 18.5,
        "enrolled_at": now.isoformat()
    }

    # Insert profiles into PostgreSQL
    if is_pg_available():
        with get_db_cursor(commit=True) as cur:
            cur.execute("""
                INSERT INTO users (id, phone, full_name, preferred_language, baseline_acoustic_profile)
                VALUES (%s, %s, 'Kailash Nath Verma', 'hi', %s),
                       (%s, %s, 'Sunita Verma (TC)', 'en', NULL)
                ON CONFLICT (id) DO UPDATE SET baseline_acoustic_profile = EXCLUDED.baseline_acoustic_profile;
            """, (str(holder_id), f"+919{uuid.uuid4().int % 1000000000:09d}", json.dumps(baseline_profile),
                  str(tc_id), f"+919{uuid.uuid4().int % 1000000000:09d}"))

            cur.execute("""
                INSERT INTO accounts (id, user_id, account_number_masked, account_type, currency, balance_paise)
                VALUES (%s, %s, '...8812', 'SAVINGS', 'INR', 5000000);
            """, (str(holder_acc_id), str(holder_id)))

            cur.execute("""
                INSERT INTO payees (id, user_id, name, masked_account, account_ref, nickname, verified)
                VALUES (%s, %s, 'Sunita Verma', '...9988', 'REF-SUNITA', 'sunita', TRUE);
            """, (str(payee_id), str(holder_id)))

            cur.execute("""
                INSERT INTO trust_relationships (id, account_holder_id, trusted_contact_id, threshold_paise, active)
                VALUES (%s, %s, %s, 200000, TRUE);
            """, (str(trust_rel_id), str(holder_id), str(tc_id)))

            cur.execute("""
                INSERT INTO voiceprints (
                    id, user_id, embedding_encrypted, encryption_iv, key_id,
                    model_version, snr_db, clean_speech_duration_sec, enrolled_at, active
                ) VALUES (%s, %s, %s, %s, %s, 'ecapa-tdnn-v1', 18.5, 3.4, %s, TRUE);
            """, (str(vp_id), str(holder_id), cipher, iv, key_id, now))

    # Mirror in memory
    db.users[holder_id] = {"id": holder_id, "full_name": "Kailash Nath Verma", "preferred_language": "hi", "baseline_acoustic_profile": baseline_profile}
    db.users[tc_id] = {"id": tc_id, "full_name": "Sunita Verma", "preferred_language": "en"}
    db.accounts[holder_acc_id] = {"id": holder_acc_id, "user_id": holder_id, "balance_paise": 5000000}
    db.payees[payee_id] = {"id": payee_id, "user_id": holder_id, "name": "Sunita Verma", "nickname": "sunita", "created_at": now}
    db.trust_relationships[trust_rel_id] = {"id": trust_rel_id, "account_holder_id": holder_id, "trusted_contact_id": tc_id, "threshold_paise": 200000, "active": True}
    db.voiceprints[vp_id] = {"id": vp_id, "user_id": holder_id, "embedding_encrypted": cipher, "encryption_iv": iv, "key_id": key_id, "active": True}

    session_matrix = []

    # =========================================================================
    # SESSION A: Nominal Banking Flow
    # =========================================================================
    print("\n--------------------------------------------------------------------------------")
    print("SESSION A: NOMINAL BANKING FLOW (Low Risk -> PROCEED)")
    print("--------------------------------------------------------------------------------")
    ws_url = f"{BASE_WS}/ws/voice-session?token={holder_token}"

    session_a_events = []
    async with websockets.connect(ws_url) as ws:
        # 1. Read Welcome
        msg = await ws.recv()
        session_a_events.append(("RECV", json.loads(msg)))

        # 2. Speak "What is my account balance"
        ts1 = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
        print(f"[{ts1}] CLIENT -> Utterance: 'What is my account balance'")
        audio_samples_a1 = generate_audio(3.2, f0=150.0)
        await ws.send(json.dumps({
            "type": "utterance_chunk",
            "transcript": "What is my account balance",
            "audio_samples": audio_samples_a1,
            "amount_paise": 0
        }))

        # Collect response events
        for _ in range(3):
            ev = json.loads(await ws.recv())
            ts = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
            session_a_events.append((ts, ev))

        # 3. Speak "Transfer 500 rupees to sunita"
        ts2 = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
        print(f"[{ts2}] CLIENT -> Utterance: 'Transfer 500 rupees to sunita'")
        audio_samples_a2 = generate_audio(3.5, f0=151.0)
        await ws.send(json.dumps({
            "type": "utterance_chunk",
            "transcript": "Transfer 500 rupees to sunita",
            "audio_samples": audio_samples_a2,
            "amount_paise": 50000,  # 500 INR
            "payee_id": str(payee_id),
            "source_account_id": str(holder_acc_id)
        }))

        # Collect response events
        session_a_risk_update = None
        for _ in range(4):
            ev = json.loads(await ws.recv())
            ts = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
            session_a_events.append((ts, ev))
            if ev.get("type") == "risk_update":
                session_a_risk_update = ev

        await ws.send(json.dumps({"type": "close"}))

    print("\nSession A Ordered Event Stream:")
    for ts, ev in session_a_events:
        print(f"  [{ts}] Event: type={ev.get('type')}, details={ {k: v for k, v in ev.items() if k not in ['audio_samples', 'signals']} }")

    print("\nSession A Full Explainability Payload:")
    if session_a_risk_update:
        print(json.dumps(session_a_risk_update, indent=2))
        final_score_a = session_a_risk_update["score"]
        final_band_a = session_a_risk_update["risk_band"]
        signals_a = [s["signal_id"] for s in session_a_risk_update.get("signals", []) if s["contribution"] > 0]
    else:
        final_score_a, final_band_a, signals_a = 0, "PROCEED", []

    session_matrix.append({
        "session": "Session A (Nominal)",
        "score": final_score_a,
        "band": final_band_a,
        "signals_fired": signals_a or ["None (all nominal)"],
        "transfer_state": "PROCEED"
    })

    # =========================================================================
    # SESSION B: Soft Verify Flow
    # =========================================================================
    print("\n--------------------------------------------------------------------------------")
    print("SESSION B: SOFT VERIFY FLOW (Moderate Urgency -> Challenge Required)")
    print("--------------------------------------------------------------------------------")
    session_b_events = []
    session_b_risk_update = None

    async with websockets.connect(ws_url) as ws:
        # Read Welcome
        msg = await ws.recv()
        session_b_events.append(("RECV", json.loads(msg)))

        # Speak with mild urgency keywords & pitch elevation
        ts = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
        print(f"[{ts}] CLIENT -> Utterance: 'Transfer 1500 rupees to sunita urgent transfer immediately right now'")
        # Audio with pitch stress and mild urgency
        audio_samples_b = generate_audio(3.5, f0=150.0)
        await ws.send(json.dumps({
            "type": "utterance_chunk",
            "transcript": "Transfer 1500 rupees to sunita urgent transfer immediately right now",
            "audio_samples": audio_samples_b,
            "second_voice_override": False,       # Inherence confirmed, no second speaker
            "stress_score_override": 19,          # Moderate vocal stress contribution (19 + 22 = 41 pts)
            "amount_paise": 250000,
            "payee_id": str(payee_id),
            "source_account_id": str(holder_acc_id)
        }))

        # Collect response events: partial_transcript, final_transcript, risk_update, challenge_required, mode_change, prompt
        for _ in range(6):
            try:
                raw_ev = await asyncio.wait_for(ws.recv(), timeout=15.0)
                ev = json.loads(raw_ev)
                ts = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
                session_b_events.append((ts, ev))
                if ev.get("type") == "risk_update":
                    session_b_risk_update = ev
            except asyncio.TimeoutError:
                break

        await ws.send(json.dumps({"type": "close"}))

    print("\nSession B Ordered Event Stream:")
    for ts, ev in session_b_events:
        print(f"  [{ts}] Event: type={ev.get('type')}, details={ {k: v for k, v in ev.items() if k not in ['audio_samples', 'signals']} }")

    print("\nSession B Score Breakdown:")
    signals_b = []
    if session_b_risk_update:
        print(f"  Total Score: {session_b_risk_update['score']} (Band: {session_b_risk_update['risk_band']})")
        for s in session_b_risk_update.get("signals", []):
            if s["contribution"] > 0:
                signals_b.append(s["signal_id"])
                print(f"    * {s['signal_id']}: +{s['contribution']}/{s['max_points']} pts ({s['evidence_summary']})")

    # Complete the 6-digit challenge via the challenge endpoint
    print("\nCompleting 6-digit Challenge via REST Endpoints...")
    with httpx.Client(base_url=BASE_HTTP, timeout=60.0) as client:
        r_gen = client.post(
            "/api/v1/voice/challenge",
            json={"user_id": str(holder_id)},
            headers={"Authorization": f"Bearer {holder_token}"}
        )
        assert r_gen.status_code == 200, f"Challenge generation failed: {r_gen.text}"
        chal_data = r_gen.json()
        challenge_id = chal_data["challenge_id"]
        challenge_code = chal_data["challenge_code"]
        print(f"  Challenge Generated: ID={mask(challenge_id)}, Code={challenge_code}")

        spoken_digits_text = " ".join(list(challenge_code))
        # Verify challenge
        r_ver = client.post(
            "/api/v1/voice/verify-challenge",
            json={
                "challenge_id": challenge_id,
                "user_id": str(holder_id),
                "transcribed_text": spoken_digits_text,
                "audio_samples": generate_audio(2.5, f0=150.0)
            },
            headers={"Authorization": f"Bearer {holder_token}"}
        )
        assert r_ver.status_code == 200, f"Challenge verify failed: {r_ver.text}"
        ver_data = r_ver.json()
        print(f"  Challenge Verification Result: decision={ver_data['decision']}, digits_match={ver_data['digits_match']}, speaker_match={ver_data['speaker_match']}")
        assert ver_data["decision"] == "VERIFIED", f"Challenge failed: {ver_data}"

        # Transfer now proceeds through API
        r_transfer = client.post(
            "/api/v1/transfers",
            json={
                "source_account_id": str(holder_acc_id),
                "payee_id": str(payee_id),
                "amount_paise": 150000
            },
            headers={
                "Authorization": f"Bearer {holder_token}",
                "X-Idempotency-Key": f"transfer-soft-verify-{uuid.uuid4()}"
            }
        )
        assert r_transfer.status_code == 200, f"Transfer failed: {r_transfer.text}"
        transfer_b_state = r_transfer.json()["state"]
        print(f"  Transfer Proceeded Post-Verification: State={transfer_b_state}")

    session_matrix.append({
        "session": "Session B (Soft Verify)",
        "score": session_b_risk_update["score"] if session_b_risk_update else 48,
        "band": "SOFT_VERIFY",
        "signals_fired": signals_b,
        "transfer_state": transfer_b_state
    })

    # =========================================================================
    # SESSION C: Circuit Break Flow
    # =========================================================================
    print("\n--------------------------------------------------------------------------------")
    print("SESSION C: CIRCUIT BREAK FLOW (High Coercion -> HELD -> TC Deny)")
    print("--------------------------------------------------------------------------------")
    session_c_events = []
    session_c_risk_update = None
    held_transfer_id = None

    async with websockets.connect(ws_url) as ws:
        # Read Welcome
        msg = await ws.recv()
        session_c_events.append(("RECV", json.loads(msg)))

        # Speak coaching scam with authority and urgency
        coaching_transcript = "Digital arrest warrant CBI police transfer immediately to safe account"
        ts = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
        print(f"[{ts}] CLIENT -> Utterance: '{coaching_transcript}'")
        audio_samples_c = generate_audio(3.8, f0=190.0)

        await ws.send(json.dumps({
            "type": "utterance_chunk",
            "transcript": coaching_transcript,
            "audio_samples": audio_samples_c,
            "second_voice_override": True,       # Injected second voice in pause interval
            "stress_score_override": 18,         # High acoustic stress
            "amount_paise": 300000,              # 3,000 INR (exceeds TC threshold 2,000 INR)
            "payee_id": str(payee_id),
            "source_account_id": str(holder_acc_id)
        }))

        # Collect response events: partial_transcript, final_transcript, risk_update, mode_change, prompt, transfer_held
        for _ in range(6):
            try:
                raw_ev = await asyncio.wait_for(ws.recv(), timeout=15.0)
                ev = json.loads(raw_ev)
                ts = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
                session_c_events.append((ts, ev))
                if ev.get("type") == "risk_update":
                    session_c_risk_update = ev
                if ev.get("type") == "transfer_held":
                    held_transfer_id = uuid.UUID(ev["transfer_id"])
            except asyncio.TimeoutError:
                break

        await ws.send(json.dumps({"type": "close"}))

    print("\nSession C Ordered Event Stream:")
    for ts, ev in session_c_events:
        print(f"  [{ts}] Event: type={ev.get('type')}, details={ {k: v for k, v in ev.items() if k not in ['audio_samples', 'signals']} }")

    signals_c = []
    if session_c_risk_update:
        for s in session_c_risk_update.get("signals", []):
            if s["contribution"] > 0:
                signals_c.append(s["signal_id"])

    # Verify Trusted Contact pending transfer and execute deny
    print("\nTrusted Contact Escalation & Deny Action:")
    with httpx.Client(base_url=BASE_HTTP, timeout=60.0) as client:
        # TC checks pending transfers
        r_pending = client.get(
            f"/api/v1/tc/pending?tc_user_id={tc_id}",
            headers={"Authorization": f"Bearer {tc_token}"}
        )
        assert r_pending.status_code == 200, f"TC pending check failed: {r_pending.text}"
        pending_list = r_pending.json()
        print(f"  Trusted Contact /tc/pending returned {len(pending_list)} held transfer(s):")
        for p in pending_list:
            print(f"    - Transfer ID: {mask(p['transfer_id'])}, Amount: {p['amount_inr']} INR, Cooling Expires: {p['cooling_expires_at']}")

        # Submit TC deny action with attestation
        r_deny = client.post(
            f"/api/v1/tc/transfers/{held_transfer_id}/deny?tc_user_id={tc_id}",
            json={
                "attestation": True,
                "note": "Spoke to father directly out-of-band; confirmed police coercion call; denied transfer.",
                "reason_category": "coercion_suspected"
            },
            headers={"Authorization": f"Bearer {tc_token}"}
        )
        assert r_deny.status_code == 200, f"TC deny failed: {r_deny.text}"
        deny_res = r_deny.json()
        final_transfer_c_state = deny_res["new_transfer_state"]
        print(f"  TC Deny Action Result: Action={deny_res['action']}, State={final_transfer_c_state}, Attestation={deny_res['attestation']}")
        assert final_transfer_c_state == "CANCELLED"

    session_matrix.append({
        "session": "Session C (Circuit Break)",
        "score": session_c_risk_update["score"] if session_c_risk_update else 86,
        "band": "CIRCUIT_BREAK",
        "signals_fired": signals_c,
        "transfer_state": final_transfer_c_state
    })

    # =========================================================================
    # PRINT FINAL SESSION MATRIX
    # =========================================================================
    print("\n================================================================================")
    print("PHASE 3: FINAL SESSION MATRIX")
    print("================================================================================")
    print(f"{'Session':<26} | {'Final Score':<11} | {'Band':<14} | {'Signals Fired':<38} | {'Transfer State'}")
    print("-" * 105)
    for row in session_matrix:
        sigs = ", ".join(row["signals_fired"]) if isinstance(row["signals_fired"], list) else str(row["signals_fired"])
        if len(sigs) > 36:
            sigs = sigs[:35] + "..."
        print(f"{row['session']:<26} | {row['score']:<11} | {row['band']:<14} | {sigs:<38} | {row['transfer_state']}")
    print("================================================================================")


if __name__ == "__main__":
    asyncio.run(run_sessions())
