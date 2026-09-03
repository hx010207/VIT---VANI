from fastapi import APIRouter, HTTPException, Request
from typing import List, Optional
import uuid
import datetime
from server.app.database import db, is_pg_available, get_db_cursor
from server.app.models.schemas import PayeeCreate, PayeeResponse
from server.app.services.audit import audit_service

router = APIRouter(prefix="/payees", tags=["payees"])


@router.get("", response_model=List[PayeeResponse])
async def list_payees(user_id: Optional[uuid.UUID] = None):
    target_user_id = user_id or uuid.UUID("11111111-1111-1111-1111-111111111111")
    if is_pg_available():
        try:
            with get_db_cursor() as cur:
                cur.execute("SELECT * FROM payees WHERE user_id = %s;", (str(target_user_id),))
                rows = cur.fetchall()
                if rows:
                    return [PayeeResponse(**dict(r)) for r in rows]
        except Exception:
            pass

    return [
        PayeeResponse(
            id=p["id"],
            user_id=p["user_id"],
            name=p["name"],
            masked_account=p["masked_account"],
            account_ref=p["account_ref"],
            nickname=p.get("nickname"),
            verified=p["verified"],
            created_at=p["created_at"]
        )
        for p in db.payees.values()
        if p["user_id"] == target_user_id
    ]


@router.post("", response_model=PayeeResponse)
async def create_payee(req: PayeeCreate, request: Request, user_id: Optional[uuid.UUID] = None):
    request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))
    target_user_id = user_id or uuid.UUID("11111111-1111-1111-1111-111111111111")

    payee_id = uuid.uuid4()
    now = datetime.datetime.now(datetime.timezone.utc)
    payee = {
        "id": payee_id,
        "user_id": target_user_id,
        "name": req.name,
        "masked_account": req.masked_account,
        "account_ref": req.account_ref,
        "nickname": req.nickname,
        "verified": True,
        "created_at": now
    }
    db.payees[payee_id] = payee

    if is_pg_available():
        try:
            with get_db_cursor(commit=True) as cur:
                cur.execute("""
                    INSERT INTO payees (id, user_id, name, masked_account, account_ref, nickname, verified, created_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT DO NOTHING;
                """, (str(payee_id), str(target_user_id), req.name, req.masked_account, req.account_ref, req.nickname, True, now))
        except Exception:
            pass

    audit_service.log(
        actor_id=str(target_user_id),
        entity="payees",
        entity_id=str(payee_id),
        action="PAYEE_CREATED",
        payload={"name": req.name, "account_ref": req.account_ref},
        request_id=request_id
    )

    return PayeeResponse(**payee)


@router.delete("/{payee_id}")
async def delete_payee(payee_id: uuid.UUID, request: Request, user_id: Optional[uuid.UUID] = None):
    request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))
    target_user_id = user_id or uuid.UUID("11111111-1111-1111-1111-111111111111")

    payee = db.payees.get(payee_id)
    if not payee or payee["user_id"] != target_user_id:
        raise HTTPException(status_code=404, detail="Payee not found")

    del db.payees[payee_id]

    audit_service.log(
        actor_id=str(target_user_id),
        entity="payees",
        entity_id=str(payee_id),
        action="PAYEE_DELETED",
        payload={},
        request_id=request_id
    )

    return {"deleted": True, "payee_id": payee_id}
