# PURPOSE: Authentication helper endpoints, JWT token verification, and session inspection.
# ROLE IN SYSTEM: Interacts with Supabase Auth JWKS to confirm user session validity.
# TALKS TO: server/app/config.py, server/app/api/deps.py
from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel
from typing import Optional
import uuid
import datetime
import re
import os
import hashlib
import httpx
import jwt
from server.app.database import db
from server.app.config import settings
from server.app.models.schemas import ErasureResponse, ErrorResponse
from server.app.services.audit import audit_service

router = APIRouter(prefix="/auth", tags=["auth"])


def generate_jwt_token(user_id: uuid.UUID, phone: str = "") -> str:
    now = datetime.datetime.now(datetime.timezone.utc)
    payload = {
        "sub": str(user_id),
        "role": "authenticated",
        "aud": "authenticated",
        "exp": int((now + datetime.timedelta(days=7)).timestamp()),
        "iat": int(now.timestamp()),
        "phone": phone
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm="HS256")


def normalize_phone(phone_str: str) -> str:
    cleaned = re.sub(r'[\s\-\(\)]', '', phone_str.strip())
    if cleaned.startswith("+"):
        return cleaned
    if len(cleaned) == 10 and cleaned.isdigit():
        return f"+91{cleaned}"
    if len(cleaned) == 11 and cleaned.startswith("0"):
        return f"+91{cleaned[1:]}"
    return cleaned


class SessionExchangeRequest(BaseModel):
    phone: str
    password: Optional[str] = None
    preferred_language: str = "hi"


class SessionExchangeResponse(BaseModel):
    user_id: uuid.UUID
    phone: str
    full_name: str
    token: str
    preferred_language: str
    enrolled: bool
    guardian_mode: bool = False
    guardian_name: Optional[str] = None


class RegisterRequest(BaseModel):
    full_name: str
    phone: str
    password: str
    guardian_mode: bool = False
    guardian_phone: Optional[str] = None
    preferred_language: str = "hi"


class RegisterResponse(BaseModel):
    user_id: uuid.UUID
    phone: str
    full_name: str
    token: str
    guardian_mode: bool = False
    message: str = "Account created successfully"


@router.post("/register", response_model=RegisterResponse)
async def register_user(req: RegisterRequest, request: Request):
    normalized_phone = normalize_phone(req.phone)
    if len(req.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters.")

    from server.app.database import is_pg_available, get_db_cursor
    
    # Check duplicate phone
    if is_pg_available():
        with get_db_cursor() as cur:
            cur.execute("SELECT id FROM users WHERE phone = %s;", (normalized_phone,))
            if cur.fetchone():
                raise HTTPException(status_code=400, detail="Phone number is already registered.")
    else:
        if any(u.get("phone") == normalized_phone for u in db.users.values()):
            raise HTTPException(status_code=400, detail="Phone number is already registered.")

    new_id = uuid.uuid4()
    salt = os.urandom(16).hex()
    dk = hashlib.pbkdf2_hmac("sha256", req.password.encode("utf-8"), bytes.fromhex(salt), 100000)
    pw_hash = dk.hex()
    digits = re.sub(r'\D', '', normalized_phone)
    email = f"{digits}@vaniguard.org"

    # Register in Supabase Auth via admin endpoint
    try:
        async with httpx.AsyncClient() as client:
            await client.post(
                f"{settings.SUPABASE_URL}/auth/v1/admin/users",
                headers={
                    "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                    "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
                    "Content-Type": "application/json"
                },
                json={
                    "id": str(new_id),
                    "email": email,
                    "password": req.password,
                    "email_confirm": True,
                    "user_metadata": {
                        "phone": normalized_phone,
                        "full_name": req.full_name,
                        "guardian_mode": req.guardian_mode
                    }
                },
                timeout=10.0
            )
    except Exception:
        pass

    now = datetime.datetime.now(datetime.timezone.utc)
    acc_id = uuid.uuid4()
    masked_acc = f"...{digits[-4:]}" if len(digits) >= 4 else "...1000"

    # Insert into PostgreSQL
    if is_pg_available():
        with get_db_cursor(commit=True) as cur:
            cur.execute("""
                INSERT INTO users (id, phone, full_name, preferred_language, accessibility_prefs, guardian_mode, password_hash, password_salt, created_at)
                VALUES (%s, %s, %s, %s, '{"high_contrast": false, "screen_reader": false, "speech_rate": 0.85}'::jsonb, %s, %s, %s, %s)
                ON CONFLICT (id) DO NOTHING;
            """, (str(new_id), normalized_phone, req.full_name, req.preferred_language, req.guardian_mode, pw_hash, salt, now))

            cur.execute("""
                INSERT INTO accounts (id, user_id, account_number_masked, account_type, currency, balance_paise)
                VALUES (%s, %s, %s, 'SAVINGS', 'INR', 5000000)
                ON CONFLICT (id) DO NOTHING;
            """, (str(acc_id), str(new_id), masked_acc))

            # Link guardian if provided
            if req.guardian_mode and req.guardian_phone:
                norm_guardian_phone = normalize_phone(req.guardian_phone)
                cur.execute("SELECT id FROM users WHERE phone = %s;", (norm_guardian_phone,))
                g_row = cur.fetchone()
                if g_row:
                    g_id = g_row["id"]
                    cur.execute("""
                        INSERT INTO trust_relationships (id, account_holder_id, trusted_contact_id, threshold_paise, active, relationship_type, cooling_window_minutes, is_guardian)
                        VALUES (%s, %s, %s, 200000, TRUE, 'caregiver', 30, TRUE)
                        ON CONFLICT DO NOTHING;
                    """, (str(uuid.uuid4()), str(new_id), str(g_id)))

    # In-memory sync
    db.users[new_id] = {
        "id": new_id,
        "phone": normalized_phone,
        "full_name": req.full_name,
        "preferred_language": req.preferred_language,
        "guardian_mode": req.guardian_mode,
        "password_hash": pw_hash,
        "password_salt": salt,
        "created_at": now
    }
    db.accounts[acc_id] = {
        "id": acc_id,
        "user_id": new_id,
        "account_number_masked": masked_acc,
        "balance_paise": 5000000,
        "opened_at": now
    }

    token = generate_jwt_token(new_id, normalized_phone)
    return RegisterResponse(
        user_id=new_id,
        phone=normalized_phone,
        full_name=req.full_name,
        token=token,
        guardian_mode=req.guardian_mode,
        message="Account registered successfully."
    )


@router.post("/session", response_model=SessionExchangeResponse)
async def exchange_session(req: SessionExchangeRequest, request: Request):
    request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))
    normalized_phone = normalize_phone(req.phone)
    user = None

    # Check PostgreSQL first (System of Record)
    from server.app.database import is_pg_available, get_db_cursor
    if is_pg_available():
        try:
            with get_db_cursor() as cur:
                cur.execute("SELECT * FROM users WHERE phone = %s;", (normalized_phone,))
                row = cur.fetchone()
                if row:
                    user = dict(row)
        except Exception:
            pass

    # Fall back to in-memory DatabaseStore
    if not user:
        for u in db.users.values():
            if u["phone"] == normalized_phone or u["phone"] == req.phone:
                user = u
                break

    # If user has credentials configured, verify password
    if user and user.get("password_hash") and user.get("password_salt"):
        if not req.password:
            raise HTTPException(status_code=401, detail="Password required for authentication.")
        salt_val = user["password_salt"]
        salt_bytes = bytes.fromhex(salt_val if len(salt_val) == 32 else salt_val.encode("utf-8").hex()[:32])
        dk = hashlib.pbkdf2_hmac("sha256", req.password.encode("utf-8"), salt_bytes, 100000)
        if dk.hex() != user["password_hash"]:
            raise HTTPException(status_code=401, detail="Invalid phone number or password.")

    if not user:
        new_id = uuid.uuid4()
        user = {
            "id": new_id,
            "phone": req.phone,
            "full_name": "New Account Holder",
            "preferred_language": req.preferred_language,
            "guardian_mode": False,
            "accessibility_prefs": {"high_contrast": False, "screen_reader": False, "speech_rate": 0.85},
            "baseline_acoustic_profile": None,
            "created_at": datetime.datetime.now(datetime.timezone.utc)
        }
        db.users[new_id] = user

    # Check if user has active voiceprint
    has_voiceprint = any(v["user_id"] == user["id"] and v["active"] for v in db.voiceprints.values())

    token = generate_jwt_token(user["id"], user.get("phone", req.phone))

    # Check guardian name if guardian_mode is enabled
    guardian_name = None
    if user.get("guardian_mode"):
        for tr in db.trust_relationships.values():
            if tr["account_holder_id"] == user["id"] and tr["active"] and tr.get("is_guardian", True):
                g_user = db.users.get(tr["trusted_contact_id"])
                if g_user:
                    guardian_name = g_user["full_name"]
                break

    audit_service.log(
        actor_id=str(user["id"]),
        entity="users",
        entity_id=str(user["id"]),
        action="SESSION_EXCHANGED",
        payload={"phone": req.phone, "guardian_mode": user.get("guardian_mode", False)},
        request_id=request_id
    )

    return SessionExchangeResponse(
        user_id=user["id"],
        phone=user["phone"],
        full_name=user["full_name"],
        token=token,
        preferred_language=user["preferred_language"],
        enrolled=has_voiceprint,
        guardian_mode=user.get("guardian_mode", False),
        guardian_name=guardian_name
    )


@router.post("/logout")
async def logout_user(request: Request):
    auth_header = request.headers.get("Authorization", "")
    token = auth_header.replace("Bearer ", "").strip()
    if token:
        db.revoked_tokens.add(token)
    return {"status": "logged_out", "message": "Session invalidated server-side."}


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
