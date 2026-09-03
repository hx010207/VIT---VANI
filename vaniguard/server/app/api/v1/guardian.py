# PURPOSE: Guardian Mode management endpoints for senior-citizen protection and trusted guardian settings.
# ROLE IN SYSTEM: Manages cooling window adjustments, always-allow payees, 24h guardian change control, and audit logs.
# TALKS TO: server/app/database.py, server/app/services/audit.py, server/app/services/notifications.py
import uuid
import datetime
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Request, Header
from pydantic import BaseModel, Field
import structlog
from server.app.database import db, is_pg_available, get_db_cursor
from server.app.services.audit import audit_service
from server.app.services.notifications import notification_manager

logger = structlog.get_logger()
router = APIRouter(prefix="/guardian", tags=["guardian"])


class CoolingWindowRequest(BaseModel):
    account_holder_id: uuid.UUID
    cooling_window_minutes: int = Field(ge=5, le=60, description="Cooling window between 5 and 60 minutes")
    guardian_attestation: bool = True
    note: Optional[str] = "Guardian shortened cooling window"


class AlwaysAllowPayeeRequest(BaseModel):
    account_holder_id: uuid.UUID
    payee_id: uuid.UUID
    note: Optional[str] = "Guardian pre-approved recurring family payee"


class GuardianChangeRequest(BaseModel):
    account_holder_id: uuid.UUID
    action: str = Field(pattern="^(CHANGE|REMOVE)$")
    proposed_guardian_phone: Optional[str] = None
    challenge_verified: bool = False


class GuardianModeToggleRequest(BaseModel):
    account_holder_id: uuid.UUID
    enabled: bool
    relationship_type: str = "caregiver"
    dpdp_consent: bool = True


@router.get("/status")
async def get_guardian_status(account_holder_id: uuid.UUID):
    """Returns comprehensive Guardian Mode status, configuration, and pre-approved payees."""
    user = None
    if is_pg_available():
        try:
            with get_db_cursor() as cur:
                cur.execute("SELECT * FROM users WHERE id = %s;", (str(account_holder_id),))
                row = cur.fetchone()
                if row:
                    user = dict(row)
        except Exception:
            pass

    if not user:
        user = db.users.get(account_holder_id)

    if not user:
        raise HTTPException(status_code=404, detail="Account holder not found")

    guardian_mode = user.get("guardian_mode", False)
    guardian_id = None
    guardian_name = None
    cooling_minutes = 30
    relationship_type = "caregiver"

    # Fetch trust relationship
    if is_pg_available():
        try:
            with get_db_cursor() as cur:
                cur.execute("""
                    SELECT tr.trusted_contact_id, tr.cooling_window_minutes, tr.relationship_type, u.full_name as guardian_name
                    FROM trust_relationships tr
                    JOIN users u ON tr.trusted_contact_id = u.id
                    WHERE tr.account_holder_id = %s AND tr.active = TRUE
                    LIMIT 1;
                """, (str(account_holder_id),))
                tr_row = cur.fetchone()
                if tr_row:
                    guardian_id = uuid.UUID(str(tr_row["trusted_contact_id"]))
                    guardian_name = tr_row["guardian_name"]
                    cooling_minutes = tr_row.get("cooling_window_minutes", 30)
                    relationship_type = tr_row.get("relationship_type", "caregiver")
        except Exception:
            pass

    if not guardian_id:
        for tr in db.trust_relationships.values():
            if tr["account_holder_id"] == account_holder_id and tr["active"]:
                guardian_id = tr["trusted_contact_id"]
                cooling_minutes = tr.get("cooling_window_minutes", 30)
                relationship_type = tr.get("relationship_type", "caregiver")
                g_user = db.users.get(guardian_id)
                if g_user:
                    guardian_name = g_user.get("full_name")
                break

    # Fetch always-allow payees
    always_allow_list = []
    if is_pg_available():
        try:
            with get_db_cursor() as cur:
                cur.execute("""
                    SELECT aap.id, aap.payee_id, p.name, p.nickname, p.masked_account, aap.approved_at
                    FROM always_allow_payees aap
                    JOIN payees p ON aap.payee_id = p.id
                    WHERE aap.account_holder_id = %s AND aap.active = TRUE;
                """, (str(account_holder_id),))
                for r in cur.fetchall():
                    always_allow_list.append({
                        "id": str(r["id"]),
                        "payee_id": str(r["payee_id"]),
                        "name": r["name"],
                        "nickname": r.get("nickname"),
                        "masked_account": r["masked_account"],
                        "approved_at": r["approved_at"].isoformat() if hasattr(r["approved_at"], "isoformat") else str(r["approved_at"])
                    })
        except Exception:
            pass

    if not always_allow_list:
        for aap in db.always_allow_payees.values():
            if aap["account_holder_id"] == account_holder_id and aap.get("active", True):
                p = db.payees.get(aap["payee_id"], {})
                always_allow_list.append({
                    "id": str(aap["id"]),
                    "payee_id": str(aap["payee_id"]),
                    "name": p.get("name", "Payee"),
                    "nickname": p.get("nickname"),
                    "masked_account": p.get("masked_account", "...0000"),
                    "approved_at": str(aap.get("approved_at", datetime.datetime.now(datetime.timezone.utc)))
                })

    # Fetch pending guardian changes
    pending_changes = []
    for gpc in db.guardian_pending_changes.values():
        if gpc["account_holder_id"] == account_holder_id and gpc["status"] == "PENDING":
            pending_changes.append({
                "id": str(gpc["id"]),
                "action": gpc["action"],
                "requested_at": str(gpc["requested_at"]),
                "effective_at": str(gpc["effective_at"]),
                "status": gpc["status"]
            })

    return {
        "account_holder_id": str(account_holder_id),
        "guardian_mode": guardian_mode,
        "guardian_id": str(guardian_id) if guardian_id else None,
        "guardian_name": guardian_name,
        "relationship_type": relationship_type,
        "cooling_window_minutes": cooling_minutes,
        "always_allow_payees": always_allow_list,
        "pending_changes": pending_changes
    }


@router.patch("/cooling-window")
async def update_cooling_window(req: CoolingWindowRequest, request: Request):
    """
    Guardian power: Shortens the cooling window down to a minimum of 5 minutes.
    API enforces cooling_window_minutes >= 5 strictly.
    """
    if req.cooling_window_minutes < 5:
        raise HTTPException(status_code=400, detail="Minimum cooling window is 5 minutes for senior-citizen safety.")

    request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))

    # Update PostgreSQL
    if is_pg_available():
        try:
            with get_db_cursor(commit=True) as cur:
                cur.execute("""
                    UPDATE trust_relationships
                    SET cooling_window_minutes = %s
                    WHERE account_holder_id = %s AND active = TRUE;
                """, (req.cooling_window_minutes, str(req.account_holder_id)))
        except Exception:
            pass

    # Update in-memory
    updated = False
    for tr in db.trust_relationships.values():
        if tr["account_holder_id"] == req.account_holder_id and tr["active"]:
            tr["cooling_window_minutes"] = req.cooling_window_minutes
            updated = True
            break

    audit_service.log(
        actor_id=str(req.account_holder_id),
        entity="guardian_settings",
        entity_id=str(req.account_holder_id),
        action="GUARDIAN_COOLING_WINDOW_UPDATED",
        payload={
            "cooling_window_minutes": req.cooling_window_minutes,
            "attestation": req.guardian_attestation,
            "note": req.note
        },
        request_id=request_id
    )

    return {
        "status": "success",
        "account_holder_id": str(req.account_holder_id),
        "cooling_window_minutes": req.cooling_window_minutes,
        "message": f"Cooling window successfully set to {req.cooling_window_minutes} minutes."
    }


@router.post("/always-allow-payees")
async def add_always_allow_payee(req: AlwaysAllowPayeeRequest, request: Request):
    """
    Guardian power: Pre-approves a specific trusted payee to skip SOFT_VERIFY spoken challenge.
    Never bypasses CIRCUIT_BREAK holds.
    """
    request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))

    # Find guardian id
    guardian_id = None
    for tr in db.trust_relationships.values():
        if tr["account_holder_id"] == req.account_holder_id and tr["active"]:
            guardian_id = tr["trusted_contact_id"]
            break

    if not guardian_id:
        guardian_id = uuid.UUID("55555555-5555-5555-5555-555555555555")

    aap_id = uuid.uuid4()
    now = datetime.datetime.now(datetime.timezone.utc)

    # Insert into PostgreSQL
    if is_pg_available():
        try:
            with get_db_cursor(commit=True) as cur:
                cur.execute("""
                    INSERT INTO always_allow_payees (id, account_holder_id, guardian_id, payee_id, active, approved_at)
                    VALUES (%s, %s, %s, %s, TRUE, %s)
                    ON CONFLICT (account_holder_id, payee_id) DO UPDATE SET active = TRUE;
                """, (str(aap_id), str(req.account_holder_id), str(guardian_id), str(req.payee_id), now))
        except Exception:
            pass

    # Insert into in-memory
    db.always_allow_payees[aap_id] = {
        "id": aap_id,
        "account_holder_id": req.account_holder_id,
        "guardian_id": guardian_id,
        "payee_id": req.payee_id,
        "active": True,
        "approved_at": now
    }

    audit_service.log(
        actor_id=str(guardian_id),
        entity="always_allow_payees",
        entity_id=str(aap_id),
        action="ALWAYS_ALLOW_PAYEE_ADDED",
        payload={"account_holder_id": str(req.account_holder_id), "payee_id": str(req.payee_id), "note": req.note},
        request_id=request_id
    )

    return {
        "status": "success",
        "id": str(aap_id),
        "account_holder_id": str(req.account_holder_id),
        "payee_id": str(req.payee_id),
        "message": "Payee pre-approved for spoken challenge bypass."
    }


@router.delete("/always-allow-payees/{payee_id}")
async def remove_always_allow_payee(payee_id: uuid.UUID, account_holder_id: uuid.UUID, request: Request):
    """Guardian power: Revokes always-allow status for a payee."""
    request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))

    if is_pg_available():
        try:
            with get_db_cursor(commit=True) as cur:
                cur.execute("""
                    UPDATE always_allow_payees SET active = FALSE
                    WHERE account_holder_id = %s AND payee_id = %s;
                """, (str(account_holder_id), str(payee_id)))
        except Exception:
            pass

    for aap in db.always_allow_payees.values():
        if aap["account_holder_id"] == account_holder_id and aap["payee_id"] == payee_id:
            aap["active"] = False

    audit_service.log(
        actor_id=str(account_holder_id),
        entity="always_allow_payees",
        entity_id=str(payee_id),
        action="ALWAYS_ALLOW_PAYEE_REMOVED",
        payload={"payee_id": str(payee_id)},
        request_id=request_id
    )

    return {"status": "success", "message": "Payee pre-approval revoked."}


@router.post("/change-request")
async def request_guardian_change(req: GuardianChangeRequest, request: Request):
    """
    Guardian change control:
    Holder can change or remove guardian only after passing spoken 6-digit challenge AND a mandatory 24h pending window.
    """
    request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))

    if not req.challenge_verified:
        raise HTTPException(
            status_code=403,
            detail="Spoken 6-digit challenge verification required before initiating guardian swap or removal."
        )

    current_guardian_id = None
    for tr in db.trust_relationships.values():
        if tr["account_holder_id"] == req.account_holder_id and tr["active"]:
            current_guardian_id = tr["trusted_contact_id"]
            break

    change_id = uuid.uuid4()
    now = datetime.datetime.now(datetime.timezone.utc)
    effective_at = now + datetime.timedelta(hours=24)

    record = {
        "id": change_id,
        "account_holder_id": req.account_holder_id,
        "current_guardian_id": current_guardian_id,
        "proposed_guardian_phone": req.proposed_guardian_phone,
        "action": req.action,
        "challenge_verified": True,
        "requested_at": now,
        "effective_at": effective_at,
        "status": "PENDING"
    }

    db.guardian_pending_changes[change_id] = record

    if is_pg_available():
        try:
            with get_db_cursor(commit=True) as cur:
                cur.execute("""
                    INSERT INTO guardian_pending_changes (id, account_holder_id, current_guardian_id, action, challenge_verified, requested_at, effective_at, status)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, 'PENDING');
                """, (str(change_id), str(req.account_holder_id), str(current_guardian_id) if current_guardian_id else None, req.action, True, now, effective_at))
        except Exception:
            pass

    # Notify current guardian of pending change
    if current_guardian_id:
        await notification_manager.broadcast_to_user(
            current_guardian_id,
            "guardian_change_alert",
            {
                "change_id": str(change_id),
                "action": req.action,
                "effective_at": effective_at.isoformat(),
                "notice": "A request to change your guardian status was initiated. It will take effect in 24 hours."
            }
        )

    audit_service.log(
        actor_id=str(req.account_holder_id),
        entity="guardian_pending_changes",
        entity_id=str(change_id),
        action=f"GUARDIAN_{req.action}_INITIATED",
        payload={"effective_at": effective_at.isoformat(), "challenge_verified": True},
        request_id=request_id
    )

    return {
        "status": "pending_scheduled",
        "change_id": str(change_id),
        "effective_at": effective_at.isoformat(),
        "cooling_hours_remaining": 24,
        "message": "Guardian modification initiated. Mandatory 24-hour protective window active. Current guardian notified."
    }


@router.post("/toggle-mode")
async def toggle_guardian_mode(req: GuardianModeToggleRequest, request: Request):
    """Toggles Guardian Mode on or off for an account holder with DPDP Act consent tracking."""
    request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))

    if not req.dpdp_consent and req.enabled:
        raise HTTPException(status_code=400, detail="Explicit DPDP consent required to activate Guardian Mode.")

    if is_pg_available():
        try:
            with get_db_cursor(commit=True) as cur:
                cur.execute("""
                    UPDATE users SET guardian_mode = %s WHERE id = %s;
                """, (req.enabled, str(req.account_holder_id)))
        except Exception:
            pass

    if req.account_holder_id in db.users:
        db.users[req.account_holder_id]["guardian_mode"] = req.enabled

    audit_service.log(
        actor_id=str(req.account_holder_id),
        entity="guardian_mode",
        entity_id=str(req.account_holder_id),
        action="GUARDIAN_MODE_TOGGLED",
        payload={"enabled": req.enabled, "relationship_type": req.relationship_type, "dpdp_consent": req.dpdp_consent},
        request_id=request_id
    )

    return {
        "status": "success",
        "account_holder_id": str(req.account_holder_id),
        "guardian_mode": req.enabled,
        "message": "Guardian Mode successfully updated."
    }
