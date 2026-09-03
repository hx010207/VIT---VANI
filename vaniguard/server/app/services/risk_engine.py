import os
import json
import numpy as np
from typing import Dict, Any, List, Tuple, Optional
from pathlib import Path
from server.app.models.schemas import (
    RiskBandEnum,
    SignalContribution,
    ExplainabilityPayload,
    RiskEngineInput
)


class CoercionRiskEngine:
    """
    Real-Time Coercion Detection and Fraud-Intervention Engine.
    Computes transparent, explainable CoercionRiskScore (0-100) from 5 independent signals.
    Invariant: All acoustic signals are self-referenced to user's enrollment baseline.
    Zero demographic, age, or gender dependencies.
    """

    def __init__(self):
        self._load_lexicons()

    def _load_lexicons(self):
        current_dir = Path(__file__).resolve().parent
        worker_dir = current_dir.parent.parent.parent / "worker"
        
        en_path = worker_dir / "scam_lexicon.en.json"
        hi_path = worker_dir / "scam_lexicon.hi.json"
        
        self.lexicon_en = []
        self.lexicon_hi = []
        
        if en_path.exists():
            with open(en_path, "r", encoding="utf-8") as f:
                self.lexicon_en = json.load(f).get("terms", [])
        if hi_path.exists():
            with open(hi_path, "r", encoding="utf-8") as f:
                self.lexicon_hi = json.load(f).get("terms", [])

    def compute_lexicon_score(self, transcript: str, language: str = "hi") -> Tuple[int, str]:
        """
        Linguistic signal: COERCION_SCRIPT_MATCH (Weight: up to 25 points).
        Scans transcript against curated scam lexicons across urgency, authority, secrecy, unusual framings.
        """
        if not transcript or not transcript.strip():
            return 0, "No speech transcript available"

        text_lower = transcript.lower()
        matched_terms = []
        accumulated_raw_weight = 0

        # Scan both lexicons to support code-switching/Hinglish
        all_terms = self.lexicon_en + self.lexicon_hi
        seen_terms = set()
        
        import re
        for item in all_terms:
            term = item["term"].lower()
            # If the term is alphanumeric/latin, use word boundaries so 'ed' does not match in 'hundred'
            if re.search(r'^[a-zA-Z0-9\s]+$', term):
                pattern = r'(?:\b|_)' + re.escape(term) + r'(?:\b|_)'
                if re.search(pattern, text_lower) and term not in seen_terms:
                    seen_terms.add(term)
                    weight = item["weight"]
                    category = item["category"]
                    matched_terms.append((term, weight, category))
                    accumulated_raw_weight += weight
            else:
                # Devanagari / unicode terms
                if term in text_lower and term not in seen_terms:
                    seen_terms.add(term)
                    weight = item["weight"]
                    category = item["category"]
                    matched_terms.append((term, weight, category))
                    accumulated_raw_weight += weight

        if not matched_terms:
            return 0, "No scam or coercion script markers detected in transcript"

        # Scale raw accumulated weight into 0-25 point range
        # Raw weight of 25+ saturates to the full 25 points
        contribution = min(25, int(round((accumulated_raw_weight / 28.0) * 25.0)))
        contribution = max(5, contribution)  # Minimum 5 points if any keyword matched

        categories = list(set(c for _, _, c in matched_terms))
        top_terms = [t for t, _, _ in matched_terms[:4]]
        evidence = f"Matched {len(matched_terms)} scam markers across [{', '.join(categories)}]: '{', '.join(top_terms)}'"
        
        return contribution, evidence

    def compute_speaker_match_score(
        self,
        enrolled_embedding: Optional[List[float]],
        live_embedding: Optional[List[float]],
        threshold: float = 0.68
    ) -> Tuple[int, str]:
        """
        Acoustic signal: SPEAKER_MISMATCH (Weight: 30 points).
        Evaluates cosine similarity of live voice vs enrolled voiceprint.
        """
        if not enrolled_embedding or not live_embedding:
            return 0, "Speaker embedding verification not active for this frame"

        v1 = np.array(enrolled_embedding)
        v2 = np.array(live_embedding)

        norm1 = np.linalg.norm(v1)
        norm2 = np.linalg.norm(v2)

        if norm1 == 0 or norm2 == 0:
            return 30, "Invalid or zero-norm speaker embedding"

        similarity = float(np.dot(v1, v2) / (norm1 * norm2))

        if similarity >= threshold:
            return 0, f"Enrolled speaker confirmed (cosine similarity: {similarity:.3f} >= threshold {threshold})"
        
        # Linear degradation below threshold
        gap = threshold - similarity
        scaled_points = int(min(30, round((gap / 0.35) * 30.0)))
        scaled_points = max(10, scaled_points)
        evidence = f"Speaker mismatch risk: cosine similarity {similarity:.3f} below threshold {threshold}"
        return scaled_points, evidence

    def compute_contextual_anomaly_score(
        self,
        amount_paise: int,
        user_90_day_max_amount_paise: int,
        user_90_day_median_paise: int,
        payee_created_hours_ago: float,
        hour_of_day_utc: int,
        consecutive_transfers_last_10m: int
    ) -> Tuple[int, str]:
        """
        Session signal: CONTEXTUAL_ANOMALY (Weight: up to 20 points).
        - Amount percentile anomaly
        - New payee age < 24h
        - Time-of-day anomaly (00:00-05:00)
        - Velocity/rapid attempts
        """
        points = 0
        reasons = []

        # 1. Amount anomaly (up to 8 points)
        if user_90_day_max_amount_paise > 0:
            if amount_paise > 2 * user_90_day_max_amount_paise:
                points += 8
                reasons.append(f"Amount exceeds 2x 90-day maximum ({amount_paise / 100:.0f} INR)")
            elif amount_paise > user_90_day_max_amount_paise:
                points += 5
                reasons.append("Amount exceeds 90-day maximum")
            elif user_90_day_median_paise > 0 and amount_paise > 4 * user_90_day_median_paise:
                points += 3
                reasons.append("Amount significantly exceeds 90-day median")

        # 2. New payee risk (up to 6 points)
        if payee_created_hours_ago < 24.0:
            points += 6
            reasons.append(f"New payee registered {payee_created_hours_ago:.1f} hours ago (< 24h)")

        # 3. Night-time transfer anomaly (00:00 - 05:00, 3 points)
        if 0 <= hour_of_day_utc <= 5:
            points += 3
            reasons.append(f"Unusual transaction hour ({hour_of_day_utc:02d}:00 UTC)")

        # 4. Rapid repeated attempts (up to 5 points)
        if consecutive_transfers_last_10m >= 3:
            points += 5
            reasons.append(f"{consecutive_transfers_last_10m} rapid transfer attempts in 10 minutes")
        elif consecutive_transfers_last_10m == 2:
            points += 3
            reasons.append("Repeated transfer attempt within 10 minutes")

        total_points = min(20, points)
        evidence = "; ".join(reasons) if reasons else "Normal transaction context"
        return total_points, evidence

    @staticmethod
    def score_to_band(score: int) -> RiskBandEnum:
        if score <= 39:
            return RiskBandEnum.PROCEED
        elif score <= 69:
            return RiskBandEnum.SOFT_VERIFY
        else:
            return RiskBandEnum.CIRCUIT_BREAK

    def evaluate_risk(
        self,
        features: RiskEngineInput,
        second_voice_result: Optional[Dict[str, Any]] = None,
        vocal_stress_result: Optional[Dict[str, Any]] = None
    ) -> ExplainabilityPayload:
        """
        Main evaluation entry point.
        Aggregates all 5 transparent signals and assigns decision band:
        - 0-39: PROCEED
        - 40-69: SOFT_VERIFY
        - 70-100: CIRCUIT_BREAK
        """
        signals = []

        # 1. SECOND_VOICE_DETECTION (35 points)
        if second_voice_result:
            sv_points = min(35, second_voice_result.get("score_points", 0))
            sv_evidence = second_voice_result.get("evidence_summary", "No secondary voice detected")
        else:
            sv_points = 0
            sv_evidence = "Second voice detection nominal"
        signals.append(SignalContribution(
            signal_id="SECOND_VOICE_DETECTION",
            contribution=sv_points,
            max_points=35,
            evidence_summary=sv_evidence
        ))

        # 2. VOCAL_STRESS_INDEX (20 points)
        if vocal_stress_result:
            vs_points = min(20, vocal_stress_result.get("score_points", 0))
            vs_evidence = vocal_stress_result.get("evidence_summary", "Vocal acoustics within self-baseline")
        else:
            vs_points = 0
            vs_evidence = "Vocal stress within normal baseline parameters"
        signals.append(SignalContribution(
            signal_id="VOCAL_STRESS_INDEX",
            contribution=vs_points,
            max_points=20,
            evidence_summary=vs_evidence
        ))

        # 3. SPEAKER_MISMATCH (30 points)
        sm_points, sm_evidence = self.compute_speaker_match_score(
            features.enrolled_embedding,
            features.live_embedding
        )
        signals.append(SignalContribution(
            signal_id="SPEAKER_MISMATCH",
            contribution=sm_points,
            max_points=30,
            evidence_summary=sm_evidence
        ))

        # 4. COERCION_SCRIPT_MATCH (25 points)
        cs_points, cs_evidence = self.compute_lexicon_score(
            features.transcript,
            features.language
        )
        signals.append(SignalContribution(
            signal_id="COERCION_SCRIPT_MATCH",
            contribution=cs_points,
            max_points=25,
            evidence_summary=cs_evidence
        ))

        # 5. CONTEXTUAL_ANOMALY (20 points)
        ca_points, ca_evidence = self.compute_contextual_anomaly_score(
            features.transaction_amount_paise,
            features.user_90_day_max_amount_paise,
            features.user_90_day_median_paise,
            features.payee_created_hours_ago,
            features.hour_of_day_utc,
            features.consecutive_transfers_last_10m
        )
        signals.append(SignalContribution(
            signal_id="CONTEXTUAL_ANOMALY",
            contribution=ca_points,
            max_points=20,
            evidence_summary=ca_evidence
        ))

        # Total score: clamped 0 to 100
        raw_total = sum(s.contribution for s in signals)
        total_score = min(100, max(0, raw_total))

        # Decision Band Mapping
        if total_score <= 39:
            band = RiskBandEnum.PROCEED
        elif total_score <= 69:
            band = RiskBandEnum.SOFT_VERIFY
        else:
            band = RiskBandEnum.CIRCUIT_BREAK

        return ExplainabilityPayload(
            total_score=total_score,
            risk_band=band,
            signals=signals
        )


risk_engine = CoercionRiskEngine()
