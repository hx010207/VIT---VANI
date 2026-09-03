import pytest
import uuid
from server.app.database import db
from server.app.models.schemas import TransferStateEnum
from server.app.services.ledger import ledger_service, InsufficientFundsError


def test_double_entry_balance_conservation():
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    acc_id = uuid.UUID("22222222-2222-2222-2222-222222222222")
    payee_id = uuid.UUID("44444444-4444-4444-4444-444444444444")
    clearing_id = uuid.UUID("33333333-3333-3333-3333-333333333333")

    initial_sender_balance = db.accounts[acc_id]["balance_paise"]
    initial_clearing_balance = db.accounts[clearing_id]["balance_paise"]
    amount = 100000  # 1,000 INR

    transfer = ledger_service.create_transfer_intent(
        user_id=user_id,
        source_account_id=acc_id,
        payee_id=payee_id,
        amount_paise=amount,
        idempotency_key=str(uuid.uuid4()),
        request_id="test-req-1"
    )

    settled = ledger_service.execute_settlement(
        transfer_id=transfer["id"],
        destination_account_id=clearing_id,
        request_id="test-req-1"
    )

    assert settled["state"] == TransferStateEnum.COMPLETED

    # Conservation check
    final_sender_balance = db.accounts[acc_id]["balance_paise"]
    final_clearing_balance = db.accounts[clearing_id]["balance_paise"]

    assert final_sender_balance == initial_sender_balance - amount
    assert final_clearing_balance == initial_clearing_balance + amount

    # Verify ledger entries pair
    entries = [e for e in db.ledger_entries if e["transfer_id"] == transfer["id"]]
    assert len(entries) == 2

    debit_legs = [e for e in entries if e["direction"] == "debit"]
    credit_legs = [e for e in entries if e["direction"] == "credit"]

    assert len(debit_legs) == 1
    assert len(credit_legs) == 1
    assert debit_legs[0]["amount_paise"] == credit_legs[0]["amount_paise"] == amount


def test_overdraft_prevention():
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    acc_id = uuid.UUID("22222222-2222-2222-2222-222222222222")
    payee_id = uuid.UUID("44444444-4444-4444-4444-444444444444")

    current_balance = db.accounts[acc_id]["balance_paise"]
    overdraft_amount = current_balance + 500000  # Exceeds balance

    with pytest.raises(InsufficientFundsError):
        ledger_service.create_transfer_intent(
            user_id=user_id,
            source_account_id=acc_id,
            payee_id=payee_id,
            amount_paise=overdraft_amount,
            idempotency_key=str(uuid.uuid4()),
            request_id="test-overdraft"
        )


def test_idempotency_key_replay_safety():
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    acc_id = uuid.UUID("22222222-2222-2222-2222-222222222222")
    payee_id = uuid.UUID("44444444-4444-4444-4444-444444444444")
    idempotency_key = f"idemp-{uuid.uuid4()}"

    transfer_1 = ledger_service.create_transfer_intent(
        user_id=user_id,
        source_account_id=acc_id,
        payee_id=payee_id,
        amount_paise=50000,
        idempotency_key=idempotency_key,
        request_id="test-idemp-1"
    )

    # Second submission with same idempotency key
    transfer_2 = ledger_service.create_transfer_intent(
        user_id=user_id,
        source_account_id=acc_id,
        payee_id=payee_id,
        amount_paise=50000,
        idempotency_key=idempotency_key,
        request_id="test-idemp-2"
    )

    assert transfer_1["id"] == transfer_2["id"]
