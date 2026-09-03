# PURPOSE: Regression test asserting cooling_expires_at is exactly now() + 30 minutes.
# ROLE IN SYSTEM: Validates that the cooling window offset is correct and timezone-aware.
# TALKS TO: server/app/services/ledger.py, server/app/database.py
import pytest
import uuid
import datetime
from server.app.database import db
from server.app.models.schemas import TransferStateEnum, RiskBandEnum
from server.app.services.ledger import ledger_service


def test_cooling_expires_at_is_exactly_30_minutes_from_now():
    """
    Regression test for GAP 4: cooling_expires_at once showed a suspicious timestamp.
    Asserts that the cooling window is within [now+29min, now+31min] at hold time.
    """
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    acc_id = uuid.UUID("22222222-2222-2222-2222-222222222222")
    payee_id = uuid.UUID("44444444-4444-4444-4444-444444444444")

    # Create a transfer intent
    transfer = ledger_service.create_transfer_intent(
        user_id=user_id,
        source_account_id=acc_id,
        payee_id=payee_id,
        amount_paise=100000,
        idempotency_key=f"cooling-test-{uuid.uuid4()}",
        request_id="test-cooling-1"
    )

    before_hold = datetime.datetime.now(datetime.timezone.utc)

    held = ledger_service.hold_transfer(
        transfer_id=transfer["id"],
        risk_score=85,
        risk_band=RiskBandEnum.CIRCUIT_BREAK,
        explainability=[],
        cooling_minutes=30,
        request_id="test-cooling-1"
    )

    after_hold = datetime.datetime.now(datetime.timezone.utc)

    expires_at = held["cooling_expires_at"]

    # Verify expires_at is timezone-aware
    assert expires_at.tzinfo is not None, "cooling_expires_at must be timezone-aware (UTC)"

    # Verify expires_at is within [now+29min, now+31min]
    earliest_acceptable = before_hold + datetime.timedelta(minutes=29)
    latest_acceptable = after_hold + datetime.timedelta(minutes=31)

    assert expires_at >= earliest_acceptable, (
        f"cooling_expires_at ({expires_at.isoformat()}) is earlier than "
        f"expected minimum ({earliest_acceptable.isoformat()})"
    )
    assert expires_at <= latest_acceptable, (
        f"cooling_expires_at ({expires_at.isoformat()}) is later than "
        f"expected maximum ({latest_acceptable.isoformat()})"
    )


def test_cooling_window_uses_utc_timezone():
    """
    Verifies that all timestamps in hold_transfer are UTC-aware,
    preventing timezone offset bugs.
    """
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    acc_id = uuid.UUID("22222222-2222-2222-2222-222222222222")
    payee_id = uuid.UUID("44444444-4444-4444-4444-444444444444")

    transfer = ledger_service.create_transfer_intent(
        user_id=user_id,
        source_account_id=acc_id,
        payee_id=payee_id,
        amount_paise=50000,
        idempotency_key=f"tz-test-{uuid.uuid4()}",
        request_id="test-tz-1"
    )

    held = ledger_service.hold_transfer(
        transfer_id=transfer["id"],
        risk_score=75,
        risk_band=RiskBandEnum.CIRCUIT_BREAK,
        explainability=[],
        cooling_minutes=30,
        request_id="test-tz-1"
    )

    expires_at = held["cooling_expires_at"]

    # Check that the timezone offset is UTC (offset 0)
    assert expires_at.utcoffset() == datetime.timedelta(0), (
        f"cooling_expires_at timezone offset is {expires_at.utcoffset()}, expected UTC (0)"
    )


def test_held_transfer_state_and_fields():
    """
    Verifies that hold_transfer sets all required fields correctly.
    """
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    acc_id = uuid.UUID("22222222-2222-2222-2222-222222222222")
    payee_id = uuid.UUID("44444444-4444-4444-4444-444444444444")

    transfer = ledger_service.create_transfer_intent(
        user_id=user_id,
        source_account_id=acc_id,
        payee_id=payee_id,
        amount_paise=75000,
        idempotency_key=f"fields-test-{uuid.uuid4()}",
        request_id="test-fields-1"
    )

    held = ledger_service.hold_transfer(
        transfer_id=transfer["id"],
        risk_score=82,
        risk_band=RiskBandEnum.CIRCUIT_BREAK,
        explainability=[{"signal_id": "TEST", "contribution": 82, "max_points": 100, "evidence_summary": "Test"}],
        cooling_minutes=30,
        request_id="test-fields-1"
    )

    assert held["state"] == TransferStateEnum.HELD
    assert held["risk_score"] == 82
    assert held["risk_band"] == RiskBandEnum.CIRCUIT_BREAK
    assert held["cooling_expires_at"] is not None
    assert len(held["explainability"]) == 1
