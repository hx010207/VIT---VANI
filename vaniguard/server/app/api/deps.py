# PURPOSE: FastAPI dependency injection for Supabase JWT authentication and JWKS token verification.
# ROLE IN SYSTEM: Validates ES256/HS256 tokens and extracts authenticated user identities.
# TALKS TO: server/app/config.py, FastAPI endpoints in server/app/api/v1/
from fastapi import Depends, HTTPException, Header, status
from typing import Optional, Dict, Any
import jwt
from jwt import PyJWKClient
import uuid
from server.app.config import settings

# Cached JWKS client for Supabase ES256 tokens
_jwks_url = f"{settings.SUPABASE_URL}/auth/v1/.well-known/jwks.json"
_jwks_client: Optional[PyJWKClient] = None

def get_jwks_client() -> PyJWKClient:
    global _jwks_client
    if _jwks_client is None:
        _jwks_client = PyJWKClient(_jwks_url, cache_keys=True, max_cached_keys=16)
    return _jwks_client


async def get_current_user(
    authorization: Optional[str] = Header(default=None),
    x_request_id: Optional[str] = Header(default=None, alias="X-Request-Id")
) -> Dict[str, Any]:
    """
    Validates Supabase-issued JWT tokens:
    - Enforces Bearer token presence in Authorization header
    - Cryptographically verifies signature:
      * ES256 user tokens verified via Supabase Auth JWKS
      * HS256 anon/service tokens verified via JWT_SECRET
    - Validates expiration (exp) and audience (aud)
    - Rejects invalid or expired tokens with standard HTTP 401
    """
    req_id = x_request_id or str(uuid.uuid4())

    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "error": {
                    "code": "UNAUTHORIZED",
                    "message": "Authorization header with Bearer token is required.",
                    "user_message_hi": "सत्यापन टोकन आवश्यक है। कृपया पुनः लॉग इन करें।",
                    "user_message_en": "Authentication token is required. Please log in again.",
                    "request_id": req_id
                }
            },
            headers={"WWW-Authenticate": "Bearer"}
        )

    token = authorization.split("Bearer ")[1].strip()

    from server.app.database import db
    if token in db.revoked_tokens:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "error": {
                    "code": "REVOKED_TOKEN",
                    "message": "Token has been revoked.",
                    "user_message_hi": "सत्र समाप्त हो गया है। कृपया पुनः लॉग इन करें।",
                    "user_message_en": "Session has been logged out. Please log in again.",
                    "request_id": req_id
                }
            },
            headers={"WWW-Authenticate": "Bearer"}
        )

    try:
        header = jwt.get_unverified_header(token)
        alg = header.get("alg", "HS256")

        if alg == "ES256":
            client = get_jwks_client()
            signing_key = client.get_signing_key_from_jwt(token)
            payload = jwt.decode(
                token,
                signing_key.key,
                algorithms=["ES256"],
                audience="authenticated",
                options={"verify_signature": True, "verify_exp": True, "verify_aud": True}
            )
        elif alg == "HS256":
            payload = jwt.decode(
                token,
                settings.JWT_SECRET,
                algorithms=["HS256"],
                options={"verify_signature": True, "verify_exp": True, "verify_aud": False}
            )
        else:
            raise jwt.InvalidAlgorithmError(f"Unsupported algorithm '{alg}'")

        # Validate audience if present
        aud = payload.get("aud")
        if aud and aud not in ["authenticated", "anon", "service_role"]:
            raise jwt.InvalidAudienceError("Token audience is invalid")

        # Extract subject user ID or role
        sub = payload.get("sub")
        if not sub and payload.get("role") not in ["service_role", "anon"]:
            raise jwt.InvalidTokenError("Token missing subject (user_id)")

        return payload

    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "error": {
                    "code": "TOKEN_EXPIRED",
                    "message": "The authentication token has expired.",
                    "user_message_hi": "आपका सुरक्षा टोकन समाप्त हो गया है। कृपया पुनः लॉग इन करें।",
                    "user_message_en": "Your security token has expired. Please log in again.",
                    "request_id": req_id
                }
            },
            headers={"WWW-Authenticate": "Bearer"}
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "error": {
                    "code": "INVALID_TOKEN",
                    "message": f"Cryptographic token validation failed: {str(e)}",
                    "user_message_hi": "सुरक्षा टोकन अमान्य है। कृपया पुनः लॉग इन करें।",
                    "user_message_en": "Security token is invalid. Please log in again.",
                    "request_id": req_id
                }
            },
            headers={"WWW-Authenticate": "Bearer"}
        )
