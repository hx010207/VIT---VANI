# PURPOSE: Administrative configuration and risk signal threshold adjustment endpoints.
# ROLE IN SYSTEM: Allows service-role inspection and dynamic tuning of risk signal weights.
# TALKS TO: server/app/database.py, server/app/services/risk_engine.py
from fastapi import APIRouter, Query
from typing import Optional, List, Dict, Any
from server.app.services.audit import audit_service
from server.app.services.risk_engine import risk_engine

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/audit")
async def get_audit_trail(
    entity: Optional[str] = Query(default=None),
    entity_id: Optional[str] = Query(default=None),
    actor_id: Optional[str] = Query(default=None)
):
    return audit_service.query(entity=entity, entity_id=entity_id, actor_id=actor_id)


@router.get("/risk-signals")
async def get_risk_signal_config():
    signals = [
        {"signal_id": "SECOND_VOICE_DETECTION", "weight": 35, "threshold": 0.40, "active": True},
        {"signal_id": "VOCAL_STRESS_INDEX", "weight": 20, "threshold": 0.50, "active": True},
        {"signal_id": "SPEAKER_MISMATCH", "weight": 30, "threshold": 0.68, "active": True},
        {"signal_id": "COERCION_SCRIPT_MATCH", "weight": 25, "threshold": 0.35, "active": True},
        {"signal_id": "CONTEXTUAL_ANOMALY", "weight": 20, "threshold": 0.60, "active": True}
    ]
    return {
        "version": "v1",
        "signals": signals,
        "lexicon_stats": {
            "english_terms": len(risk_engine.lexicon_en),
            "hindi_terms": len(risk_engine.lexicon_hi),
            "total_terms": len(risk_engine.lexicon_en) + len(risk_engine.lexicon_hi)
        }
    }
