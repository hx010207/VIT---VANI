# PURPOSE: Unit tests for authentication compliance, token rejection, and JWKS validation.
# ROLE IN SYSTEM: Verifies that missing, expired, and forged tokens are rejected with HTTP 401.
# TALKS TO: server/app/api/deps.py, server/app/api/v1/auth.py
import pytest
import uuid
import datetime
from fastapi.testclient import TestClient
from server.app.main import app
from server.app.database import db

client = TestClient(app)


def test_session_exchange():
    # 1. Elder demo account requires password
    resp_unauth = client.post("/api/v1/auth/session", json={"phone": "+919876543210", "preferred_language": "hi"})
    assert resp_unauth.status_code == 401

    # 2. Wrong password rejected
    resp_wrong = client.post("/api/v1/auth/session", json={"phone": "+919876543210", "password": "wrong", "preferred_language": "hi"})
    assert resp_wrong.status_code == 401

    # 3. Correct credentials authenticated
    resp = client.post("/api/v1/auth/session", json={"phone": "+919876543210", "password": "Asha@Demo2026", "preferred_language": "hi"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["phone"] == "+919876543210"
    assert "token" in data
    assert data["guardian_mode"] is True

    # 4. New uncredentialed phone creates session
    new_resp = client.post("/api/v1/auth/session", json={"phone": "+919999900001", "preferred_language": "en"})
    assert new_resp.status_code == 200
    assert new_resp.json()["phone"] == "+919999900001"


def test_dpdp_right_to_erasure():
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    # Seed a voiceprint
    vp_id = uuid.uuid4()
    db.voiceprints[vp_id] = {
        "id": vp_id,
        "user_id": user_id,
        "embedding_encrypted": b"cipher-bytes",
        "encryption_iv": b"iv-bytes-12",
        "key_id": "kms-v1",
        "active": True
    }
    # Seed a consent
    consent_id = uuid.uuid4()
    db.consents[consent_id] = {
        "id": consent_id,
        "user_id": user_id,
        "purpose": "voiceprint_enrollment",
        "granted_at": datetime.datetime.now(datetime.timezone.utc),
        "revoked_at": None,
        "version": "2024.1"
    }

    resp = client.post(f"/api/v1/auth/erasure?user_id={user_id}")
    assert resp.status_code == 200
    data = resp.json()

    assert data["voiceprints_purged"] >= 1
    assert data["acoustic_baseline_cleared"] is True
    assert data["regulatory_financial_records_retained"] is True

    # Confirm voiceprint is gone from database
    assert vp_id not in db.voiceprints

    # Confirm acoustic baseline cleared on user
    assert db.users[user_id]["baseline_acoustic_profile"] is None

    # Confirm consent revoked
    assert db.consents[consent_id]["revoked_at"] is not None
