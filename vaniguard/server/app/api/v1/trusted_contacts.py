from fastapi import APIRouter, HTTPException, Request
from typing import List, Optional
import uuid
import datetime
from server.app.database import db
from server.app.models.schemas import TrustedContactInvite, TrustedContactResponse
from server.app.services.audit import audit_service

router = APIRouter(prefix="/trusted-contacts", tags=["trusted_contacts"])


@router.get("", response_model=List[TrustedContactResponse])
async def list_trusted_contacts(user_id: Optional[uuid.UUID] = None):
    target_user_id = user_id or uuid.UUID("11111111-1111-1111-1111-111111111111")
    results = []
    for tr in db.trust_relationships.values():
        if tr["account_holder_id"] == target_user_id and tr["active"]:
            tc_user = db.users.get(tr["trusted_contact_id"], {})
            results.append(TrustedContactResponse(
                id=tr["id"],
                account_holder_id=tr["account_holder_id"],
                trusted_contact_id=tr["trusted_contact_id"],
                trusted_contact_name=tc_user.get("full_name", "Trusted Contact"),
                threshold_paise=tr["threshold_paise"],
                active=tr["active"],
                created_at=tr["created_at"]
            ))
    return results


@router.post("", response_model=TrustedContactResponse)
async def create_trusted_contact(
    req: TrustedContactInvite,
    request: Request,
    user_id: Optional[uuid.UUID] = None
):
    request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))
    target_user_id = user_id or uuid.UUID("11111111-1111-1111-1111-111111111111")

    # Find or register trusted contact user
    tc_user = None
    for u in db.users.values():
        if u["phone"] == req.trusted_contact_phone:
            tc_user = u
            break

    if not tc_user:
        new_tc_id = uuid.uuid4()
        tc_user = {
            "id": new_tc_id,
            "phone": req.trusted_contact_phone,
            "full_name": "Trusted Contact",
            "preferred_language": "en",
            "accessibility_prefs": {"high_contrast": False, "screen_reader": False, "speech_rate": 1.0},
            "baseline_acoustic_profile": None,
            "created_at": datetime.datetime.now(datetime.timezone.utc)
        }
        db.users[new_tc_id] = tc_user

    if tc_user["id"] == target_user_id:
        raise HTTPException(status_code=400, detail="Account holder cannot be their own trusted contact")

    rel_id = uuid.uuid4()
    now = datetime.datetime.now(datetime.timezone.utc)
    rel = {
        "id": rel_id,
        "account_holder_id": target_user_id,
        "trusted_contact_id": tc_user["id"],
        "threshold_paise": req.threshold_paise,
        "active": True,
        "created_at": now
    }
    db.trust_relationships[rel_id] = rel

    audit_service.log(
        actor_id=str(target_user_id),
        entity="trust_relationships",
        entity_id=str(rel_id),
        action="TRUSTED_CONTACT_DESIGNATED",
        payload={"trusted_contact_phone": req.trusted_contact_phone, "threshold_paise": req.threshold_paise},
        request_id=request_id
    )

    return TrustedContactResponse(
        id=rel["id"],
        account_holder_id=rel["account_holder_id"],
        trusted_contact_id=rel["trusted_contact_id"],
        trusted_contact_name=tc_user["full_name"],
        threshold_paise=rel["threshold_paise"],
        active=rel["active"],
        created_at=rel["created_at"]
    )


@router.delete("/{rel_id}")
async def revoke_trusted_contact(
    rel_id: uuid.UUID,
    request: Request,
    user_id: Optional[uuid.UUID] = None
):
    request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))
    target_user_id = user_id or uuid.UUID("11111111-1111-1111-1111-111111111111")

    rel = db.trust_relationships.get(rel_id)
    if not rel or rel["account_holder_id"] != target_user_id:
        raise HTTPException(status_code=404, detail="Trust relationship not found or unauthorized")

    rel["active"] = False
    rel["revoked_at"] = datetime.datetime.now(datetime.timezone.utc)

    audit_service.log(
        actor_id=str(target_user_id),
        entity="trust_relationships",
        entity_id=str(rel_id),
        action="TRUSTED_CONTACT_REVOKED",
        payload={},
        request_id=request_id
    )

    return {"revoked": True, "trust_id": rel_id}
