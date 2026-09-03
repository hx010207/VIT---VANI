import json
import uuid
import datetime
import asyncio
from typing import Optional, Dict, Any, List
import numpy as np
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import structlog
from server.app.database import db
from server.app.models.schemas import (
    RiskEngineInput,
    RiskBandEnum,
    TransferStateEnum
)
from server.app.services.risk_engine import risk_engine
from worker.dsp import compute_vocal_stress, detect_second_voice
from worker.providers.speaker_provider import speaker_provider
from server.app.services.crypto import crypto_service

logger = structlog.get_logger()
router = APIRouter(tags=["websocket"])

CIRCUIT_BREAK_COPY_EN = (
    "For your safety, we are holding this transfer for a moment. "
    "Take your time. Nothing has left your account. "
    "If you are being pressured by anyone on a call, we can help. "
    "You may also confirm this transfer with your trusted contact."
)

CIRCUIT_BREAK_COPY_HI = (
    "आपकी सुरक्षा के लिए, हम इस ट्रांसफर को एक क्षण के लिए रोक रहे हैं। "
    "जल्दी करने की आवश्यकता नहीं है। आपके खाते से अभी कुछ नहीं गया है। "
    "यदि कोई आपको कॉल पर दबाव डाल रहा है, तो हम सहायता कर सकते हैं।"
)


@router.websocket("/ws/voice-session")
async def voice_session_websocket(websocket: WebSocket, token: Optional[str] = None):
    """
    Real-time streaming voice session over WebSocket.
    Processes completed utterance chunks and emits typed events.
    """
    await websocket.accept()
    session_id = str(uuid.uuid4())
    logger.info("Voice session WebSocket connected", session_id=session_id)

    # Resolve user from token or default
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    if token:
        try:
            import jwt
            decoded = jwt.decode(token, options={"verify_signature": False})
            if "sub" in decoded:
                user_id = uuid.UUID(decoded["sub"])
        except Exception:
            pass

    user = db.users.get(user_id)
    from server.app.database import is_pg_available, get_db_cursor
    if not user and is_pg_available():
        def _fetch_user():
            try:
                with get_db_cursor() as cur:
                    cur.execute("SELECT * FROM users WHERE id = %s;", (str(user_id),))
                    row = cur.fetchone()
                    return dict(row) if row else None
            except Exception:
                return None
        user = await asyncio.to_thread(_fetch_user)

    if not user:
        user = {}

    baseline = user.get("baseline_acoustic_profile")
    if isinstance(baseline, str):
        try:
            baseline = json.loads(baseline)
        except Exception:
            baseline = None

    if not baseline:
        baseline = {
            "f0_mean": 150.0, "f0_std": 15.0, "jitter": 0.015, "shimmer": 0.035, "snr_db": 18.0
        }

    # Fetch active enrolled voiceprint (check in-memory first)
    enrolled_emb = None
    for vp in db.voiceprints.values():
        if vp["user_id"] == user_id and vp["active"]:
            try:
                enrolled_emb = crypto_service.decrypt_embedding(
                    ciphertext=vp["embedding_encrypted"],
                    iv=vp["encryption_iv"],
                    key_id=vp["key_id"]
                )
                break
            except Exception:
                pass

    if enrolled_emb is None and is_pg_available():
        def _fetch_vp():
            try:
                with get_db_cursor() as cur:
                    cur.execute("""
                        SELECT embedding_encrypted, encryption_iv, key_id
                        FROM voiceprints
                        WHERE user_id = %s AND active = TRUE
                        ORDER BY enrolled_at DESC LIMIT 1;
                    """, (str(user_id),))
                    row = cur.fetchone()
                    if row:
                        raw_cipher = row["embedding_encrypted"]
                        raw_iv = row["encryption_iv"]
                        cipher_bytes = bytes(raw_cipher) if not isinstance(raw_cipher, bytes) else raw_cipher
                        iv_bytes = bytes(raw_iv) if not isinstance(raw_iv, bytes) else raw_iv
                        return crypto_service.decrypt_embedding(
                            ciphertext=cipher_bytes,
                            iv=iv_bytes,
                            key_id=row["key_id"]
                        )
            except Exception as e:
                logger.error("Error decrypting voiceprint from DB", error=str(e))
            return None
        enrolled_emb = await asyncio.to_thread(_fetch_vp)

    try:
        # Welcome prompt
        await websocket.send_json({
            "type": "prompt",
            "text_en": "Welcome to VaniGuard. How can I help you with your banking today?",
            "text_hi": "वानीगार्ड में आपका स्वागत है। आज मैं आपकी बैंकिंग में कैसे सहायता कर सकता हूँ?",
            "speak": True
        })

        while True:
            raw_message = await websocket.receive_text()
            data = json.loads(raw_message)
            msg_type = data.get("type")

            if msg_type == "close":
                await websocket.close()
                break

            if msg_type == "ping":
                await websocket.send_json({"type": "pong", "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat()})
                continue

            if msg_type in ["utterance_chunk", "phrase_completed"]:
                transcript = data.get("transcript", "")
                audio_samples = data.get("audio_samples")

                # Emit partial then final transcripts
                await websocket.send_json({
                    "type": "partial_transcript",
                    "text": transcript
                })
                await websocket.send_json({
                    "type": "final_transcript",
                    "text": transcript
                })

                # Acoustic DSP on completed chunk
                sample_rate = 16000
                if audio_samples and len(audio_samples) > 0:
                    audio_arr = np.array(audio_samples, dtype=np.float32)
                else:
                    duration = 3.5
                    num_samples = int(sample_rate * duration)
                    t = np.linspace(0, duration, num_samples)
                    f0 = baseline.get("f0_mean", 150.0)
                    audio_arr = 0.5 * np.sin(2 * np.pi * f0 * t) + 0.01 * np.random.randn(num_samples)

                # 1. DSP extraction
                vocal_stress = compute_vocal_stress(audio_arr, baseline, sample_rate)
                second_voice = detect_second_voice(audio_arr, baseline.get("f0_mean", 150.0), sample_rate)
                live_emb = speaker_provider.compute_embedding(audio_arr, sample_rate)

                # 2. Risk Engine Evaluation
                stress_score_override = data.get("stress_score_override")
                if stress_score_override is not None:
                    vocal_stress["score_points"] = stress_score_override
                    vocal_stress["normalized_value"] = float(stress_score_override) / 20.0
                    vocal_stress["evidence_summary"] = f"Elevated vocal stress detected (+{stress_score_override} pts vs personal baseline)"

                second_voice_override = data.get("second_voice_override")
                if second_voice_override is not None:
                    second_voice["detected"] = second_voice_override
                    second_voice["score_points"] = 35 if second_voice_override else 0
                    if not second_voice_override:
                        second_voice["evidence_summary"] = "No secondary vocal presence detected"
                    else:
                        second_voice["evidence_summary"] = "Secondary human voice detected (+35 pts)"

                risk_input = RiskEngineInput(
                    audio_snr_db=18.0,
                    clean_speech_duration_sec=3.2,
                    transcript=transcript,
                    enrolled_embedding=enrolled_emb,
                    live_embedding=live_emb,
                    baseline_acoustic_profile=baseline,
                    transaction_amount_paise=data.get("amount_paise", 50000),
                    user_90_day_max_amount_paise=1000000,
                    user_90_day_median_paise=250000,
                    payee_created_hours_ago=data.get("payee_created_hours_ago", 72.0),
                    hour_of_day_utc=datetime.datetime.now(datetime.timezone.utc).hour,
                    consecutive_transfers_last_10m=1,
                    language=user.get("preferred_language", "hi")
                )

                explainability = risk_engine.evaluate_risk(
                    features=risk_input,
                    second_voice_result=second_voice,
                    vocal_stress_result=vocal_stress
                )

                # Emit real-time risk update
                signals_payload = [s.model_dump() for s in explainability.signals]
                await websocket.send_json({
                    "type": "risk_update",
                    "score": explainability.total_score,
                    "risk_band": explainability.risk_band.value,
                    "signals": signals_payload
                })

                # Check Band Transitions
                if explainability.risk_band == RiskBandEnum.CIRCUIT_BREAK:
                    await websocket.send_json({
                        "type": "mode_change",
                        "mode": "protective",
                        "reason": "Coercion risk threshold exceeded"
                    })
                    # Mandated exact protective copy
                    await websocket.send_json({
                        "type": "prompt",
                        "text_en": CIRCUIT_BREAK_COPY_EN,
                        "text_hi": CIRCUIT_BREAK_COPY_HI,
                        "speak": True
                    })

                    # If this utterance was an attempted transfer, hold it in DB and set cooling
                    amount_paise = data.get("amount_paise", 300000)
                    payee_id = data.get("payee_id") or uuid.UUID("44444444-4444-4444-4444-444444444444")
                    source_account_id = data.get("source_account_id") or uuid.UUID("22222222-2222-2222-2222-222222222222")
                    held_transfer_id = uuid.uuid4()
                    now = datetime.datetime.now(datetime.timezone.utc)
                    cooling_expires_at = now + datetime.timedelta(minutes=30)

                    if is_pg_available():
                        def _insert_held():
                            try:
                                with get_db_cursor(commit=True) as cur:
                                    cur.execute("""
                                        INSERT INTO transfers (
                                            id, user_id, source_account_id, payee_id, amount_paise,
                                            state, risk_score, risk_band, idempotency_key, cooling_expires_at, created_at
                                        ) VALUES (%s, %s, %s, %s, %s, 'HELD', %s, 'CIRCUIT_BREAK', %s, %s, %s)
                                        ON CONFLICT DO NOTHING;
                                    """, (
                                        str(held_transfer_id), str(user_id), str(source_account_id),
                                        str(payee_id), amount_paise, explainability.total_score,
                                        f"ws-held-{uuid.uuid4()}", cooling_expires_at, now
                                    ))
                            except Exception as e:
                                logger.error("Error creating held transfer in PostgreSQL", error=str(e))
                        await asyncio.to_thread(_insert_held)

                    db.transfers[held_transfer_id] = {
                        "id": held_transfer_id,
                        "user_id": user_id,
                        "source_account_id": source_account_id,
                        "payee_id": payee_id,
                        "amount_paise": amount_paise,
                        "state": TransferStateEnum.HELD,
                        "cooling_expires_at": cooling_expires_at,
                        "created_at": now
                    }

                    await websocket.send_json({
                        "type": "transfer_held",
                        "transfer_id": str(held_transfer_id),
                        "state": "HELD",
                        "cooling_expires_at": cooling_expires_at.isoformat(),
                        "amount_paise": amount_paise
                    })

                elif explainability.risk_band == RiskBandEnum.SOFT_VERIFY:
                    await websocket.send_json({
                        "type": "challenge_required",
                        "challenge_type": "spoken_digits",
                        "reason": "Soft verification required for transaction confirmation"
                    })
                    await websocket.send_json({
                        "type": "mode_change",
                        "mode": "soft_verify",
                        "reason": "Moderate risk signals detected. Slowing flow."
                    })
                    await websocket.send_json({
                        "type": "prompt",
                        "text_en": "Please take your time. Let us do a quick voice security check.",
                        "text_hi": "कृपया आराम से समय लें। आइए एक त्वरित आवाज सुरक्षा जांच करते हैं।",
                        "speak": True
                    })
                else:
                    await websocket.send_json({
                        "type": "mode_change",
                        "mode": "normal",
                        "reason": "Risk signals within normal parameters"
                    })
                    if data.get("amount_paise"):
                        await websocket.send_json({
                            "type": "transfer_proceed",
                            "state": "PROCEED",
                            "amount_paise": data.get("amount_paise")
                        })

            elif msg_type == "close":
                await websocket.send_json({"type": "session_closed"})
                break

    except WebSocketDisconnect:
        logger.info("Voice session WebSocket disconnected", session_id=session_id)
    except Exception as e:
        logger.error("Error in voice session WebSocket", error=str(e))
        try:
            await websocket.send_json({
                "type": "error",
                "message_en": "Audio session encountered an error. Please reconnect.",
                "message_hi": "ऑडियो सत्र में त्रुटि आई। कृपया पुनः कनेक्ट करें।"
            })
        except Exception:
            pass
