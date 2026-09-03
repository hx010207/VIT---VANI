from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel
import uuid
import datetime
from server.app.database import db
from server.app.models.schemas import ErasureResponse, ErrorResponse
from server.app.services.audit import audit_service

router = APIRouter(prefix="/auth", tags=["auth"])


class SessionExchangeRequest(BaseModel):
    phone: str
    preferred_language: str = "hi"


class SessionExchangeResponse(BaseModel):
    user_id: uuid.UUID
    phone: str
    full_name: str
    token: str
    preferred_language: str
    enrolled: bool


@router.post("/session", response_model=SessionExchangeResponse)
async def exchange_session(req: SessionExchangeRequest, request: Request):
    request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))
    # Match existing user or register
    user = None
    for u in db.users.values():
        if u["phone"] == req.phone:
            user = u
            break

    if not user:
        new_id = uuid.uuid4()
        user = {
            "id": new_id,
            "phone": req.phone,
            "full_name": "New Account Holder",
            "preferred_language": req.preferred_language,
            "accessibility_prefs": {"high_contrast": False, "screen_reader": False, "speech_rate": 0.85},
            "baseline_acoustic_profile": None,
            "created_at": datetime.datetime.now(datetime.timezone.utc)
        }
        db.users[new_id] = user

    # Check if user has active voiceprint
    has_voiceprint = any(v["user_id"] == user["id"] and v["active"] for v in db.voiceprints.values())

    token = f"jwt-session-{user['id']}-{int(datetime.datetime.now(datetime.timezone.utc).timestamp())}"

    audit_service.log(
        actor_id=str(user["id"]),
        entity="users",
        entity_id=str(user["id"]),
        action="SESSION_EXCHANGED",
        payload={"phone": req.phone},
        request_id=request_id
    )

    return SessionExchangeResponse(
        user_id=user["id"],
        phone=user["phone"],
        full_name=user["full_name"],
        token=token,
        preferred_language=user["preferred_language"],
        enrolled=has_voiceprint
    )


@router.post("/erasure", response_model=ErasureResponse)
async def request_right_to_erasure(
    user_id: uuid.UUID,
    request: Request,
    x_request_id: str = Header(default="erasure-req")
):
    """
    DPDP Act 2023 Right-to-Erasure Endpoint.
    Purges voiceprint embeddings, acoustic baseline, and revokes consents.
    Retains double-entry financial ledger records as mandated by RBI compliance retention regulations.
    """
    if user_id not in db.users:
        raise HTTPException(status_code=404, detail="User not found")

    # Purge voiceprints
    voiceprints_purged = 0
    to_delete = [vid for vid, v in db.voiceprints.items() if v["user_id"] == user_id]
    for vid in to_delete:
        del db.voiceprints[vid]
        voiceprints_purged += 1

    # Clear baseline profile
    user = db.users[user_id]
    user["baseline_acoustic_profile"] = None

    # Revoke all active consents
    consents_revoked = 0
    now = datetime.datetime.now(datetime.timezone.utc)
    for c in db.consents.values():
        if c["user_id"] == user_id and c["revoked_at"] is None:
            c["revoked_at"] = now
            consents_revoked += 1

    audit_service.log(
        actor_id=str(user_id),
        entity="compliance",
        entity_id=str(user_id),
        action="RIGHT_TO_ERASURE_EXECUTED",
        payload={
            "voiceprints_purged": voiceprints_purged,
            "consents_revoked": consents_revoked
        },
        request_id=x_request_id
    )

    return ErasureResponse(
        user_id=user_id,
        voiceprints_purged=voiceprints_purged,
        consents_revoked=consents_revoked,
        acoustic_baseline_cleared=True,
        regulatory_financial_records_retained=True,
        completed_at=now,
        retention_notice="Biometric templates and consents purged. Core double-entry transaction ledgers retained in accordance with RBI AML/CFT regulatory schedule."
    )
