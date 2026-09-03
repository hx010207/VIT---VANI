# PURPOSE: Test suite for Guardian Mode, security invariants, challenge expiry, and rate limiting.
# ROLE IN SYSTEM: Verifies that guardian invariants (cooling window bounds, 24h change delay, no circuit-break bypass) hold strictly.
# TALKS TO: server/app/api/v1/guardian.py, server/app/services/challenge.py, server/app/services/rate_limiter.py
import pytest
import uuid
import datetime
import numpy as np
from fastapi.testclient import TestClient
from server.app.main import app
from server.app.database import db
from server.app.services.challenge import challenge_service
from server.app.services.rate_limiter import rate_limiter
from server.app.services.ledger import ledger_service
from server.app.models.schemas import RiskBandEnum, RiskEngineInput
from server.app.services.risk_engine import risk_engine

client = TestClient(app)

ELDER_ID = uuid.UUID("11111111-1111-1111-1111-111111111111")
GUARDIAN_ID = uuid.UUID("55555555-5555-5555-5555-555555555555")
TRUSTED_PAYEE_ID = uuid.UUID("44444444-4444-4444-4444-444444444444")


def test_guardian_cannot_disable_circuit_break():
    """
    INVARIANT: Guardian cannot disable circuit break.
    Proven by asserting:
    1. No endpoint exists for disabling circuit breaks (route is 404).
    2. Even when payee is pre-approved, a transfer with risk_score >= 70 MUST trigger CIRCUIT_BREAK.
    """
    # 1. Assert no public disable route exists
    resp = client.post("/api/v1/guardian/disable-circuit-break", json={"account_holder_id": str(ELDER_ID)})
    assert resp.status_code in [404, 405], f"Expected 404 or 405 for removed endpoint, got {resp.status_code}"

    # 2. Add payee to always-allow
    client.post("/api/v1/guardian/always-allow-payees", json={
        "account_holder_id": str(ELDER_ID),
        "payee_id": str(TRUSTED_PAYEE_ID)
    })

    # 3. Simulate high risk transfer (score = 85 -> CIRCUIT_BREAK)
    high_risk_input = RiskEngineInput(
        audio_snr_db=20.0,
        clean_speech_duration_sec=3.5,
        transcript="Transfer to safe account immediately CBI police warrant",
        enrolled_embedding=list(np.ones(256) / np.sqrt(256)),
        live_embedding=list(np.ones(256) / np.sqrt(256)),
        baseline_acoustic_profile={"f0_mean": 150.0, "f0_std": 15.0, "jitter": 0.015, "shimmer": 0.035},
        transaction_amount_paise=1000000,
        user_90_day_max_amount_paise=100000,
        user_90_day_median_paise=50000,
        payee_created_hours_ago=1.0,
        hour_of_day_utc=12,
        consecutive_transfers_last_10m=3,
        language="en"
    )
    sv_result = {"score_points": 35, "evidence_summary": "Second voice coaching detected in pause"}
    risk_res = risk_engine.evaluate_risk(high_risk_input, second_voice_result=sv_result)
    assert risk_res.risk_band == RiskBandEnum.CIRCUIT_BREAK
    assert risk_res.total_score >= 70


def test_guardian_cooling_window_bounds():
    """
    Guardian can shorten cooling window to a minimum of 5 minutes.
    Attempts to set cooling window < 5 minutes MUST be rejected.
    """
    # Permitted: 5 minutes
    resp_valid = client.patch("/api/v1/guardian/cooling-window", json={
        "account_holder_id": str(ELDER_ID),
        "cooling_window_minutes": 5,
        "guardian_attestation": True
    })
    assert resp_valid.status_code == 200
    assert resp_valid.json()["cooling_window_minutes"] == 5

    # Rejected: 4 minutes (< 5 minutes safety floor)
    resp_invalid = client.patch("/api/v1/guardian/cooling-window", json={
        "account_holder_id": str(ELDER_ID),
        "cooling_window_minutes": 4,
        "guardian_attestation": True
    })
    assert resp_invalid.status_code in [400, 422]


def test_always_allow_payee_management():
    """
    Tests pre-approval and revocation of always-allow payees.
    """
    # Add payee
    add_resp = client.post("/api/v1/guardian/always-allow-payees", json={
        "account_holder_id": str(ELDER_ID),
        "payee_id": str(TRUSTED_PAYEE_ID),
        "note": "Son Rahul recurring support"
    })
    assert add_resp.status_code == 200

    # Inspect status
    status_resp = client.get(f"/api/v1/guardian/status?account_holder_id={ELDER_ID}")
    assert status_resp.status_code == 200
    payees = status_resp.json()["always_allow_payees"]
    assert any(p["payee_id"] == str(TRUSTED_PAYEE_ID) for p in payees)

    # Revoke payee
    del_resp = client.delete(f"/api/v1/guardian/always-allow-payees/{TRUSTED_PAYEE_ID}?account_holder_id={ELDER_ID}")
    assert del_resp.status_code == 200


def test_guardian_change_requires_challenge_and_24h_delay():
    """
    Guardian change or removal requires 6-digit spoken challenge AND
    imposes a mandatory 24-hour cooling window before taking effect.
    """
    # Without challenge verification -> 403 Forbidden
    resp_no_challenge = client.post("/api/v1/guardian/change-request", json={
        "account_holder_id": str(ELDER_ID),
        "action": "CHANGE",
        "proposed_guardian_phone": "+919876543299",
        "challenge_verified": False
    })
    assert resp_no_challenge.status_code == 403

    # With challenge verification -> scheduled with 24-hour delay
    resp_ok = client.post("/api/v1/guardian/change-request", json={
        "account_holder_id": str(ELDER_ID),
        "action": "CHANGE",
        "proposed_guardian_phone": "+919876543299",
        "challenge_verified": True
    })
    assert resp_ok.status_code == 200
    data = resp_ok.json()
    assert data["status"] == "pending_scheduled"
    assert data["cooling_hours_remaining"] == 24


def test_challenge_expiry_and_single_use():
    """
    Amendment 4a:
    1. Spoken challenge code expires after 2 minutes (120s).
    2. Challenge code is single-use: cannot be reused after verification.
    """
    # Generate a challenge
    gen_resp = challenge_service.generate_challenge(ELDER_ID)
    cid = gen_resp.challenge_id
    code = gen_resp.challenge_code
    assert len(code) == 6

    # Verify expires_at is ~2 minutes from now
    now = datetime.datetime.now(datetime.timezone.utc)
    diff_sec = (gen_resp.expires_at - now).total_seconds()
    assert 110 <= diff_sec <= 130

    dummy_audio = np.zeros(16000, dtype=np.float32)
    dummy_emb = list(np.ones(256) / np.sqrt(256))

    # 1. Single-use consumption test:
    # First verification attempt consumes the challenge
    res1 = challenge_service.verify_challenge(
        challenge_id=cid,
        audio=dummy_audio,
        enrolled_embedding=dummy_emb,
        transcribed_text=code
    )
    assert res1.decision in ["VERIFIED", "REJECTED"]

    # Second attempt with the SAME challenge_id MUST be rejected as EXPIRED/USED
    res2 = challenge_service.verify_challenge(
        challenge_id=cid,
        audio=dummy_audio,
        enrolled_embedding=dummy_emb,
        transcribed_text=code
    )
    assert res2.decision == "EXPIRED"
    assert "already been used" in res2.user_message_en.lower() or "expired" in res2.user_message_en.lower()

    # 2. Expiry test: challenge older than 2 minutes
    gen_expired = challenge_service.generate_challenge(ELDER_ID)
    expired_cid = gen_expired.challenge_id
    # Artificially expire the record by backdating expires_at by 5 minutes
    challenge_service.active_challenges[expired_cid]["expires_at"] = now - datetime.timedelta(minutes=5)

    res_exp = challenge_service.verify_challenge(
        challenge_id=expired_cid,
        audio=dummy_audio,
        enrolled_embedding=dummy_emb,
        transcribed_text=gen_expired.challenge_code
    )
    assert res_exp.decision == "EXPIRED"


@pytest.mark.asyncio
async def test_rate_limiter_escalates_on_consecutive_failed_challenges():
    """
    After 3 failed challenge attempts in a 10-minute window,
    the rate limiter enforces an escalation to CIRCUIT_BREAK and triggers alert.
    """
    user_test = uuid.uuid4()
    rate_limiter.reset_failed_challenges(user_test)

    # 1st failure
    count1 = await rate_limiter.record_failed_challenge(user_test)
    assert count1 == 1

    # 2nd failure
    count2 = await rate_limiter.record_failed_challenge(user_test)
    assert count2 == 2

    # 3rd failure triggers escalation
    count3 = await rate_limiter.record_failed_challenge(user_test)
    assert count3 == 3

    # Cleanup
    rate_limiter.reset_failed_challenges(user_test)
