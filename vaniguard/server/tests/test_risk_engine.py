import pytest
import numpy as np
from server.app.models.schemas import RiskEngineInput, RiskBandEnum
from server.app.services.risk_engine import risk_engine


def make_nominal_features(transcript: str = "Send 500 rupees to grocer", amount_paise: int = 50000):
    return RiskEngineInput(
        audio_snr_db=20.0,
        clean_speech_duration_sec=3.5,
        transcript=transcript,
        enrolled_embedding=list(np.ones(256) / np.sqrt(256)),
        live_embedding=list(np.ones(256) / np.sqrt(256)),  # 100% match
        baseline_acoustic_profile={"f0_mean": 150.0, "f0_std": 15.0, "jitter": 0.015, "shimmer": 0.035},
        transaction_amount_paise=amount_paise,
        user_90_day_max_amount_paise=1000000,
        user_90_day_median_paise=250000,
        payee_created_hours_ago=72.0,
        hour_of_day_utc=12,
        consecutive_transfers_last_10m=1,
        language="en"
    )


def test_coercion_engine_nominal_flow():
    features = make_nominal_features()
    payload = risk_engine.evaluate_risk(features)

    assert payload.total_score <= 39
    assert payload.risk_band == RiskBandEnum.PROCEED
    assert len(payload.signals) == 5
    for s in payload.signals:
        assert s.signal_id in [
            "SECOND_VOICE_DETECTION",
            "VOCAL_STRESS_INDEX",
            "SPEAKER_MISMATCH",
            "COERCION_SCRIPT_MATCH",
            "CONTEXTUAL_ANOMALY"
        ]
        assert s.contribution >= 0
        assert s.max_points > 0
        assert len(s.evidence_summary) > 0


def test_coercion_engine_band_boundaries():
    # Boundary 1: 0-39 -> PROCEED
    features = make_nominal_features()
    payload = risk_engine.evaluate_risk(features)
    assert payload.total_score <= 39
    assert payload.risk_band == RiskBandEnum.PROCEED

    # Boundary 2: 40-69 -> SOFT_VERIFY
    # Inject speaker mismatch (30 points) + minor context anomaly (10 points) = 40 points
    impostor_emb = list(-1.0 * np.ones(256) / np.sqrt(256))
    features.live_embedding = impostor_emb
    features.transaction_amount_paise = 2500000  # 2.5x 90-day max (+8 pts)
    features.payee_created_hours_ago = 2.0        # new payee (+6 pts)

    payload = risk_engine.evaluate_risk(features)
    assert 40 <= payload.total_score <= 69
    assert payload.risk_band == RiskBandEnum.SOFT_VERIFY

    # Boundary 3: 70-100 -> CIRCUIT_BREAK
    # Second voice (35) + Speaker mismatch (30) + Scam script match (25) = 90 points
    sv_result = {"score_points": 35, "evidence_summary": "Second voice coaching detected in pause"}
    features.transcript = "Transfer to safe account immediately CBI police arrest warrant"
    payload_cb = risk_engine.evaluate_risk(features, second_voice_result=sv_result)

    assert payload_cb.total_score >= 70
    assert payload_cb.risk_band == RiskBandEnum.CIRCUIT_BREAK


def test_exact_decision_band_boundaries_0_39_40_69_70_100():
    """
    Explicitly asserts band mappings for exact boundary scores:
    0, 39 -> PROCEED
    40, 69 -> SOFT_VERIFY
    70, 100 -> CIRCUIT_BREAK
    """
    assert risk_engine.score_to_band(0) == RiskBandEnum.PROCEED
    assert risk_engine.score_to_band(39) == RiskBandEnum.PROCEED
    assert risk_engine.score_to_band(40) == RiskBandEnum.SOFT_VERIFY
    assert risk_engine.score_to_band(69) == RiskBandEnum.SOFT_VERIFY
    assert risk_engine.score_to_band(70) == RiskBandEnum.CIRCUIT_BREAK
    assert risk_engine.score_to_band(100) == RiskBandEnum.CIRCUIT_BREAK


def test_second_voice_weight():
    features = make_nominal_features()
    sv_result = {"score_points": 35, "evidence_summary": "Coaching voice in pause"}
    payload = risk_engine.evaluate_risk(features, second_voice_result=sv_result)
    sv_signal = next(s for s in payload.signals if s.signal_id == "SECOND_VOICE_DETECTION")
    assert sv_signal.contribution == 35
    assert sv_signal.max_points == 35


def test_vocal_stress_weight():
    features = make_nominal_features()
    vs_result = {"score_points": 20, "evidence_summary": "Pitch variance elevated 2.2x"}
    payload = risk_engine.evaluate_risk(features, vocal_stress_result=vs_result)
    vs_signal = next(s for s in payload.signals if s.signal_id == "VOCAL_STRESS_INDEX")
    assert vs_signal.contribution == 20
    assert vs_signal.max_points == 20


def test_scam_script_multilingual_match():
    risk_engine._load_lexicons()
    # English
    en_score, en_ev = risk_engine.compute_lexicon_score(
        "Digital arrest warrant from CBI. Transfer money to safe account immediately.", "en"
    )
    assert en_score >= 20
    assert "cbi" in en_ev.lower() or "safe account" in en_ev.lower()

    # Hindi
    hi_score, hi_ev = risk_engine.compute_lexicon_score(
        "तुरंत सत्यापन खाते में पैसा भेजो, पुलिस आ रही है।", "hi"
    )
    assert hi_score >= 15
    assert "तुरंत" in hi_ev or "सत्यापन खाते" in hi_ev or "सत्यापन खाता" in hi_ev
