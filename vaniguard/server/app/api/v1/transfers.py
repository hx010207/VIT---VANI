# PURPOSE: Money transfer initiation, idempotency control, and risk band enforcement.
# ROLE IN SYSTEM: Executes atomic double-entry ledger commits or holds high-risk transfers.
# TALKS TO: server/app/services/ledger.py, server/app/services/risk_engine.py, server/app/database.py
from fastapi import APIRouter, Header, HTTPException, Request, Depends
from typing import Optional, List, Dict, Any
import uuid
import datetime
from server.app.database import db, is_pg_available, get_db_cursor
from server.app.api.deps import get_current_user
from server.app.models.schemas import (
    TransferCreateRequest,
    TransferResponse,
    TransferStateEnum,
    RiskBandEnum,
    RiskEngineInput,
    SignalContribution
)
from server.app.services.ledger import (
    ledger_service,
    InsufficientFundsError,
    InvalidTransferStateError
)
from server.app.services.risk_engine import risk_engine

router = APIRouter(prefix="/transfers", tags=["transfers"])


@router.post("", response_model=TransferResponse)
async def initiate_transfer(
    req: TransferCreateRequest,
    request: Request,
    x_idempotency_key: str = Header(..., description="Unique client idempotency key"),
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))
    sub = current_user.get("sub")
    target_user_id = uuid.UUID(sub) if sub else uuid.UUID("11111111-1111-1111-1111-111111111111")

    # 1. Create intent via double-entry ledger service
    try:
        transfer = ledger_service.create_transfer_intent(
            user_id=target_user_id,
            source_account_id=req.source_account_id,
            payee_id=req.payee_id,
            amount_paise=req.amount_paise,
            idempotency_key=x_idempotency_key,
            request_id=request_id
        )
    except InsufficientFundsError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # If this was an idempotent replay of an already processed transfer, return as-is
    if transfer["state"] in [TransferStateEnum.COMPLETED, TransferStateEnum.HELD, TransferStateEnum.CANCELLED]:
        return TransferResponse(
            id=transfer["id"],
            user_id=transfer["user_id"],
            source_account_id=transfer["source_account_id"],
            payee_id=transfer["payee_id"],
            amount_paise=transfer["amount_paise"],
            state=transfer["state"],
            risk_score=transfer.get("risk_score"),
            risk_band=transfer.get("risk_band"),
            explainability=[SignalContribution(**s) if isinstance(s, dict) else s for s in transfer.get("explainability", [])],
            idempotency_key=transfer["idempotency_key"],
            cooling_expires_at=transfer.get("cooling_expires_at"),
            created_at=transfer["created_at"],
            final_at=transfer.get("final_at")
        )

    # 2. Risk Assessment
    payee = db.payees.get(req.payee_id)
    if payee and payee.get("created_at"):
        created_at = payee["created_at"]
        if isinstance(created_at, str):
            created_at = datetime.datetime.fromisoformat(created_at)
        payee_hours_ago = (datetime.datetime.now(datetime.timezone.utc) - created_at).total_seconds() / 3600.0
    else:
        payee_hours_ago = 24.0

    user = db.users.get(target_user_id, {})
    baseline_profile = user.get("baseline_acoustic_profile") or {"f0_mean": 150.0, "f0_std": 16.0, "jitter": 0.015, "shimmer": 0.035}

    risk_input = RiskEngineInput(
        audio_snr_db=18.0,
        clean_speech_duration_sec=3.2,
        transcript=req.transcript or "",
        enrolled_embedding=None,
        live_embedding=None,
        baseline_acoustic_profile=baseline_profile,
        transaction_amount_paise=req.amount_paise,
        user_90_day_max_amount_paise=1000000,  # 10,000 INR
        user_90_day_median_paise=250000,       # 2,500 INR
        payee_created_hours_ago=payee_hours_ago,
        hour_of_day_utc=datetime.datetime.now(datetime.timezone.utc).hour,
        consecutive_transfers_last_10m=1,
        language=user.get("preferred_language", "hi")
    )

    # Optional second voice and vocal stress injections for testability
    sv_result = {"score_points": 35, "evidence_summary": "Second voice coaching detected"} if req.second_voice_detected else None
    vs_result = {"score_points": req.voice_stress_score or 20, "evidence_summary": "Elevated vocal stress detected"} if req.voice_stress_score else None

    # Resilient fail-closed evaluation
    try:
        explainability_payload = risk_engine.evaluate_risk(
            risk_input,
            second_voice_result=sv_result,
            vocal_stress_result=vs_result
        )
        score = explainability_payload.total_score
        band = explainability_payload.risk_band
        explainability_dicts = [s.model_dump() for s in explainability_payload.signals]
    except Exception as re_err:
        logger.error("Risk engine failure, failing closed to SOFT_VERIFY", error=str(re_err))
        score = 55
        band = RiskBandEnum.SOFT_VERIFY
        explainability_dicts = []
        explainability_payload = type("Obj", (), {
            "total_score": 55,
            "risk_band": RiskBandEnum.SOFT_VERIFY,
            "signals": []
        })()

    # Check always_allow_payees: pre-approved by guardian to skip spoken challenge
    is_always_allow = False
    if is_pg_available():
        try:
            with get_db_cursor() as cur:
                cur.execute("""
                    SELECT 1 FROM always_allow_payees
                    WHERE account_holder_id = %s AND payee_id = %s AND active = TRUE
                    LIMIT 1;
                """, (str(target_user_id), str(req.payee_id)))
                if cur.fetchone():
                    is_always_allow = True
        except Exception:
            pass

    if not is_always_allow:
        for aap in db.always_allow_payees.values():
            if aap["account_holder_id"] == target_user_id and aap["payee_id"] == req.payee_id and aap.get("active", True):
                is_always_allow = True
                break

    # If always-allow matches AND band is SOFT_VERIFY: skip spoken challenge, proceed!
    # INVARIANT: CIRCUIT_BREAK is NEVER bypassed by always_allow.
    if is_always_allow and band == RiskBandEnum.SOFT_VERIFY:
        logger.info("Payee is pre-approved in always_allow list; bypassing spoken challenge", payee_id=str(req.payee_id))
        band = RiskBandEnum.PROCEED

    from server.app.services.notifications import notification_manager
    payee = db.payees.get(req.payee_id, {})

    # 3. Decision Band Execution
    if band == RiskBandEnum.CIRCUIT_BREAK:
        # Determine account-specific cooling window
        cooling_minutes = 30
        for tr in db.trust_relationships.values():
            if tr["account_holder_id"] == target_user_id and tr["active"]:
                cooling_minutes = tr.get("cooling_window_minutes", 30)
                break

        # Trigger Circuit-Break: Hold transfer, start cooling window, zero money moves
        held_transfer = ledger_service.hold_transfer(
            transfer_id=transfer["id"],
            risk_score=score,
            risk_band=band,
            explainability=explainability_dicts,
            cooling_minutes=cooling_minutes,
            request_id=request_id
        )

        # Immediately notify guardian and holder over WebSocket
        await notification_manager.notify_circuit_break(
            holder_id=target_user_id,
            transfer_id=held_transfer["id"],
            amount_paise=req.amount_paise,
            payee_name=payee.get("name", "Payee"),
            risk_score=score,
            cooling_minutes=cooling_minutes
        )

        return TransferResponse(
            id=held_transfer["id"],
            user_id=held_transfer["user_id"],
            source_account_id=held_transfer["source_account_id"],
            payee_id=held_transfer["payee_id"],
            amount_paise=held_transfer["amount_paise"],
            state=held_transfer["state"],
            risk_score=held_transfer["risk_score"],
            risk_band=held_transfer["risk_band"],
            explainability=explainability_payload.signals,
            idempotency_key=held_transfer["idempotency_key"],
            cooling_expires_at=held_transfer["cooling_expires_at"],
            created_at=held_transfer["created_at"],
            final_at=held_transfer.get("final_at")
        )
    elif band == RiskBandEnum.SOFT_VERIFY:
        transfer["state"] = TransferStateEnum.VOICE_VERIFIED
        transfer["risk_score"] = score
        transfer["risk_band"] = band
        transfer["explainability"] = explainability_dicts
        return TransferResponse(
            id=transfer["id"],
            user_id=transfer["user_id"],
            source_account_id=transfer["source_account_id"],
            payee_id=transfer["payee_id"],
            amount_paise=transfer["amount_paise"],
            state=transfer["state"],
            risk_score=score,
            risk_band=band,
            explainability=explainability_payload.signals,
            idempotency_key=transfer["idempotency_key"],
            cooling_expires_at=None,
            created_at=transfer["created_at"],
            final_at=None
        )
    else:
        # PROCEED: Atomically execute double-entry ledger settlement
        settled = await ledger_service.execute_settlement_fast(
            transfer_id=transfer["id"],
            request_id=request_id
        )
        if settled is None:
            settled = ledger_service.execute_settlement(
                transfer_id=transfer["id"],
                request_id=request_id
            )
        settled["risk_score"] = score
        settled["risk_band"] = band
        settled["explainability"] = explainability_dicts

        # Broadcast transfer_completed to both parties for live balance refresh
        tc_id = None
        for tr in db.trust_relationships.values():
            if tr["account_holder_id"] == target_user_id and tr["active"]:
                tc_id = tr["trusted_contact_id"]
                break

        await notification_manager.notify_transfer_status(
            transfer_id=settled["id"],
            status="transfer_completed",
            holder_id=target_user_id,
            tc_id=tc_id,
            amount_paise=req.amount_paise,
            payee_name=payee.get("name", "Payee")
        )

        return TransferResponse(
            id=settled["id"],
            user_id=settled["user_id"],
            source_account_id=settled["source_account_id"],
            payee_id=settled["payee_id"],
            amount_paise=settled["amount_paise"],
            state=settled["state"],
            risk_score=score,
            risk_band=band,
            explainability=explainability_payload.signals,
            idempotency_key=settled["idempotency_key"],
            cooling_expires_at=None,
            created_at=settled["created_at"],
            final_at=settled.get("final_at")
        )


@router.get("/{transfer_id}", response_model=TransferResponse)
async def get_transfer_details(
    transfer_id: uuid.UUID,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    # Check live DB if available
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

    if not transfer:
        raise HTTPException(status_code=404, detail="Transfer not found")

    return TransferResponse(
        id=transfer["id"],
        user_id=transfer["user_id"],
        source_account_id=transfer["source_account_id"],
        payee_id=transfer["payee_id"],
        amount_paise=transfer["amount_paise"],
        state=transfer["state"],
        risk_score=transfer.get("risk_score"),
        risk_band=transfer.get("risk_band"),
        explainability=[SignalContribution(**s) if isinstance(s, dict) else s for s in transfer.get("explainability", [])],
        idempotency_key=transfer["idempotency_key"],
        cooling_expires_at=transfer.get("cooling_expires_at"),
        created_at=transfer["created_at"],
        final_at=transfer.get("final_at")
    )


@router.post("/{transfer_id}/cancel", response_model=TransferResponse)
async def cancel_held_transfer(
    transfer_id: uuid.UUID,
    request: Request,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))
    sub = current_user.get("sub")
    target_user_id = uuid.UUID(sub) if sub else uuid.UUID("11111111-1111-1111-1111-111111111111")

    transfer = db.transfers.get(transfer_id)
    if not transfer:
        raise HTTPException(status_code=404, detail="Transfer not found")

    if transfer["user_id"] != target_user_id:
        raise HTTPException(status_code=403, detail="Only account holder can cancel a held transfer")

    try:
        cancelled = ledger_service.cancel_transfer(
            transfer_id=transfer_id,
            actor_id=str(target_user_id),
            reason="Account holder cancelled transfer during cooling window",
            request_id=request_id
        )
    except InvalidTransferStateError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return TransferResponse(
        id=cancelled["id"],
        user_id=cancelled["user_id"],
        source_account_id=cancelled["source_account_id"],
        payee_id=cancelled["payee_id"],
        amount_paise=cancelled["amount_paise"],
        state=cancelled["state"],
        risk_score=cancelled.get("risk_score"),
        risk_band=cancelled.get("risk_band"),
        explainability=[SignalContribution(**s) if isinstance(s, dict) else s for s in cancelled.get("explainability", [])],
        idempotency_key=cancelled["idempotency_key"],
        cooling_expires_at=cancelled.get("cooling_expires_at"),
        created_at=cancelled["created_at"],
        final_at=cancelled.get("final_at")
    )
