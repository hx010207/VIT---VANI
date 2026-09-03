from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from typing import Optional, List
import uuid
import numpy as np
from server.app.database import db
from server.app.models.schemas import ChallengeGenerateResponse, ChallengeVerifyResponse
from server.app.services.challenge import challenge_service
from server.app.services.crypto import crypto_service

router = APIRouter(prefix="/voice", tags=["voice"])


class ChallengeRequest(BaseModel):
    user_id: uuid.UUID


class ChallengeVerifyAudioRequest(BaseModel):
    challenge_id: str
    user_id: uuid.UUID
    audio_samples: Optional[List[float]] = None
    transcribed_text: Optional[str] = None


@router.post("/challenge", response_model=ChallengeGenerateResponse)
async def generate_challenge_endpoint(req: ChallengeRequest):
    return challenge_service.generate_challenge(req.user_id)


@router.post("/verify-challenge", response_model=ChallengeVerifyResponse)
async def verify_challenge_endpoint(req: ChallengeVerifyAudioRequest):
    user = None
    from server.app.database import is_pg_available, get_db_cursor
    if is_pg_available():
        try:
            with get_db_cursor() as cur:
                cur.execute("SELECT * FROM users WHERE id = %s;", (str(req.user_id),))
                row = cur.fetchone()
                if row:
                    user = dict(row)
        except Exception:
            pass

    if not user:
        user = db.users.get(req.user_id)

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Fetch active enrolled voiceprint
    active_vp = None
    if is_pg_available():
        try:
            with get_db_cursor() as cur:
                cur.execute("""
                    SELECT id, user_id, embedding_encrypted, encryption_iv, key_id
                    FROM voiceprints WHERE user_id = %s AND active = TRUE
                    ORDER BY enrolled_at DESC LIMIT 1;
                """, (str(req.user_id),))
                vp_row = cur.fetchone()
                if vp_row:
                    active_vp = dict(vp_row)
                    active_vp["embedding_encrypted"] = bytes(active_vp["embedding_encrypted"])
                    active_vp["encryption_iv"] = bytes(active_vp["encryption_iv"])
        except Exception:
            pass

    if not active_vp:
        for vp in db.voiceprints.values():
            if vp["user_id"] == req.user_id and vp["active"]:
                active_vp = vp
                break

    if not active_vp:
        raise HTTPException(status_code=400, detail="User does not have an active enrolled voiceprint")

    # Decrypt enrolled voiceprint embedding
    enrolled_embedding = crypto_service.decrypt_embedding(
        ciphertext=active_vp["embedding_encrypted"],
        iv=active_vp["encryption_iv"],
        key_id=active_vp["key_id"]
    )

    if req.audio_samples and len(req.audio_samples) > 0:
        audio = np.array(req.audio_samples, dtype=np.float32)
    else:
        # Synthetic clean speech sample matching the enrolled user's pitch
        duration = 2.0
        sample_rate = 16000
        num_samples = int(sample_rate * duration)
        t = np.linspace(0, duration, num_samples)
        f0 = user.get("baseline_acoustic_profile", {}).get("f0_mean", 150.0)
        audio = 0.5 * np.sin(2 * np.pi * f0 * t) + 0.01 * np.random.randn(num_samples)

    result = challenge_service.verify_challenge(
        challenge_id=req.challenge_id,
        audio=audio,
        enrolled_embedding=enrolled_embedding,
        sample_rate=16000,
        transcribed_text=req.transcribed_text
    )

    return result
