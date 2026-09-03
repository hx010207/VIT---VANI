import pytest
import uuid
import datetime
from server.app.database import db
from server.app.models.schemas import TransferStateEnum, RiskBandEnum
from server.app.services.sweeper import cooling_sweeper


def test_cooling_window_sweeper_auto_cancels_expired_held_transfers():
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    transfer_id = uuid.uuid4()
    now = datetime.datetime.now(datetime.timezone.utc)
    expired_time = now - datetime.timedelta(minutes=5)  # Expired 5 minutes ago

    # Seed a held transfer that has expired
    db.transfers[transfer_id] = {
        "id": transfer_id,
        "user_id": user_id,
        "source_account_id": uuid.UUID("22222222-2222-2222-2222-222222222222"),
        "payee_id": uuid.UUID("44444444-4444-4444-4444-444444444444"),
        "amount_paise": 1000000,
        "state": TransferStateEnum.HELD,
        "risk_score": 85,
        "risk_band": RiskBandEnum.CIRCUIT_BREAK,
        "explainability": [],
        "idempotency_key": str(uuid.uuid4()),
        "cooling_expires_at": expired_time,
        "created_at": now - datetime.timedelta(minutes=35),
        "final_at": None
    }

    # Run sweeper
    cancelled_ids = cooling_sweeper.sweep_expired_transfers()

    assert str(transfer_id) in cancelled_ids
    assert db.transfers[transfer_id]["state"] == TransferStateEnum.CANCELLED
    assert db.transfers[transfer_id]["final_at"] is not None

    # Check audit log
    audit_records = [
        r for r in db.audit_log
        if r["entity_id"] == str(transfer_id) and r["action"] == "COOLING_EXPIRED_AUTO_CANCEL"
    ]
    assert len(audit_records) == 1
