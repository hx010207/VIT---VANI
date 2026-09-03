from fastapi import APIRouter, HTTPException, Request
from typing import List, Optional
import uuid
import datetime
from server.app.database import db, is_pg_available, get_db_cursor
from server.app.models.schemas import (
    TCActionRequest,
    TCActionResponse,
    TCActionTypeEnum,
    TransferStateEnum
)
from server.app.services.ledger import ledger_service
from server.app.services.audit import audit_service

router = APIRouter(prefix="/tc", tags=["trusted_contact_actions"])


@router.get("/pending")
async def get_pending_transfers_for_tc(tc_user_id: Optional[uuid.UUID] = None):
    # Default to seeded TC Priya if not provided
    target_tc_id = tc_user_id or uuid.UUID("55555555-5555-5555-5555-555555555555")

    # 1. Query PostgreSQL if available
    if is_pg_available():
        try:
            with get_db_cursor() as cur:
                cur.execute("""
                    SELECT t.id, t.amount_paise, t.cooling_expires_at, t.created_at,
                           u.full_name as account_holder_name,
                           p.name as payee_name, p.masked_account as payee_account_masked
                    FROM transfers t
                    JOIN users u ON t.user_id = u.id
                    JOIN payees p ON t.payee_id = p.id
                    JOIN trust_relationships tr ON tr.account_holder_id = t.user_id
                    WHERE t.state = 'HELD'
                      AND tr.trusted_contact_id = %s
                      AND tr.active = TRUE
                      AND t.amount_paise >= tr.threshold_paise;
                """, (str(target_tc_id),))
                rows = cur.fetchall()
                if rows is not None and len(rows) > 0:
                    return [
                        {
                            "transfer_id": r["id"],
                            "account_holder_name": r["account_holder_name"],
                            "amount_paise": r["amount_paise"],
                            "amount_inr": r["amount_paise"] / 100.0,
                            "payee_name": r["payee_name"],
                            "payee_account_masked": r["payee_account_masked"],
                            "cooling_expires_at": r["cooling_expires_at"],
                            "held_since": r["created_at"]
                        }
                        for r in rows
                    ]
        except Exception:
            pass

    # 2. In-memory query fallback
    active_relationships = {
        tr["account_holder_id"]: tr["threshold_paise"]
        for tr in db.trust_relationships.values()
        if tr["trusted_contact_id"] == target_tc_id and tr["active"]
    }

    pending = []
    for t in db.transfers.values():
        if t["state"] == TransferStateEnum.HELD and t["user_id"] in active_relationships:
            threshold = active_relationships[t["user_id"]]
            if t["amount_paise"] >= threshold:
                holder = db.users.get(t["user_id"], {})
                payee = db.payees.get(t["payee_id"], {})
                # Data minimization: Never balance, never full account number
                pending.append({
                    "transfer_id": t["id"],
                    "account_holder_name": holder.get("full_name", "Account Holder"),
                    "amount_paise": t["amount_paise"],
                    "amount_inr": t["amount_paise"] / 100.0,
                    "payee_name": payee.get("name", "Unknown Payee"),
                    "payee_account_masked": payee.get("masked_account", "...0000"),
                    "cooling_expires_at": t.get("cooling_expires_at"),
                    "held_since": t["created_at"]
                })

    return pending


@router.post("/transfers/{transfer_id}/approve", response_model=TCActionResponse)
async def approve_held_transfer(
    transfer_id: uuid.UUID,
    req: TCActionRequest,
    request: Request,
    tc_user_id: Optional[uuid.UUID] = None
):
    request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))
    target_tc_id = tc_user_id or uuid.UUID("55555555-5555-5555-5555-555555555555")

    transfer = None
    if is_pg_available():
        try:
            with get_db_cursor() as cur:
                cur.execute("SELECT * FROM transfers WHERE id = %s", (str(transfer_id),))
                row = cur.fetchone()
                if row:
                    transfer = dict(row)
        except Exception:
            pass

    if not transfer:
        transfer = db.transfers.get(transfer_id)

    if not transfer or transfer["state"] != TransferStateEnum.HELD:
        raise HTTPException(status_code=404, detail="Held transfer not found or already settled")

    # Verify active trust relationship
    authorized = any(
        tr["account_holder_id"] == transfer["user_id"] and
        tr["trusted_contact_id"] == target_tc_id and
        tr["active"] and
        transfer["amount_paise"] >= tr["threshold_paise"]
        for tr in db.trust_relationships.values()
    )
    if not authorized:
        raise HTTPException(status_code=403, detail="Unauthorized to resolve this transfer")

    # Mandatory out-of-band contact confirmation attestation
    if not req.attestation:
        raise HTTPException(
            status_code=400,
            detail="Mandatory Attestation Required: Trusted Contact must confirm speaking directly with the account holder out-of-band."
        )

    now = datetime.datetime.now(datetime.timezone.utc)
    action_id = uuid.uuid4()
    db.tc_actions[action_id] = {
        "id": action_id,
        "transfer_id": transfer_id,
        "trusted_contact_id": target_tc_id,
        "action": TCActionTypeEnum.APPROVE,
        "attestation": True,
        "attested_at": now,
        "note": req.note,
        "reason_category": None
    }

    # Execute atomic settlement now that trusted contact has confirmed
    settled = ledger_service.execute_settlement(
        transfer_id=transfer_id,
        request_id=request_id
    )

    audit_service.log(
        actor_id=str(target_tc_id),
        entity="tc_actions",
        entity_id=str(action_id),
        action="TC_TRANSFER_APPROVED",
        payload={"transfer_id": str(transfer_id), "attestation": True, "note": req.note},
        request_id=request_id
    )

    return TCActionResponse(
        id=action_id,
        transfer_id=transfer_id,
        trusted_contact_id=target_tc_id,
        action=TCActionTypeEnum.APPROVE,
        attestation=True,
        attested_at=now,
        new_transfer_state=settled["state"]
    )


@router.post("/transfers/{transfer_id}/deny", response_model=TCActionResponse)
async def deny_held_transfer(
    transfer_id: uuid.UUID,
    req: TCActionRequest,
    request: Request,
    tc_user_id: Optional[uuid.UUID] = None
):
    request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))
    target_tc_id = tc_user_id or uuid.UUID("55555555-5555-5555-5555-555555555555")

    transfer = None
    if is_pg_available():
        try:
            with get_db_cursor(commit=True) as cur:
                cur.execute("SELECT * FROM transfers WHERE id = %s", (str(transfer_id),))
                row = cur.fetchone()
                if row:
                    transfer = dict(row)
                if transfer and transfer["state"] == TransferStateEnum.HELD:
                    cur.execute("""
                        INSERT INTO tc_actions (id, transfer_id, trusted_contact_id, action, attestation, attested_at, note, reason_category)
                        VALUES (%s, %s, %s, 'deny', %s, %s, %s, %s)
                        ON CONFLICT DO NOTHING;
                    """, (
                        str(uuid.uuid4()), str(transfer_id), str(target_tc_id),
                        req.attestation, datetime.datetime.now(datetime.timezone.utc),
                        req.note, req.reason_category or "suspected_coercion"
                    ))
        except Exception:
            pass

    if not transfer:
        transfer = db.transfers.get(transfer_id)

    if not transfer or transfer["state"] != TransferStateEnum.HELD:
        raise HTTPException(status_code=404, detail="Held transfer not found")

    now = datetime.datetime.now(datetime.timezone.utc)
    action_id = uuid.uuid4()
    db.tc_actions[action_id] = {
        "id": action_id,
        "transfer_id": transfer_id,
        "trusted_contact_id": target_tc_id,
        "action": TCActionTypeEnum.DENY,
        "attestation": req.attestation,
        "attested_at": now,
        "note": req.note,
        "reason_category": req.reason_category or "suspected_coercion"
    }

    cancelled = ledger_service.cancel_transfer(
        transfer_id=transfer_id,
        actor_id=str(target_tc_id),
        reason=f"Trusted contact denied transfer: {req.reason_category or 'coercion suspected'}",
        request_id=request_id
    )

    audit_service.log(
        actor_id=str(target_tc_id),
        entity="tc_actions",
        entity_id=str(action_id),
        action="TC_TRANSFER_DENIED",
        payload={"transfer_id": str(transfer_id), "reason_category": req.reason_category},
        request_id=request_id
    )

    return TCActionResponse(
        id=action_id,
        transfer_id=transfer_id,
        trusted_contact_id=target_tc_id,
        action=TCActionTypeEnum.DENY,
        attestation=req.attestation,
        attested_at=now,
        new_transfer_state=cancelled["state"]
    )
