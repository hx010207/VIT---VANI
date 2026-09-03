# PURPOSE: Pydantic schemas, request/response models, and enums for all API operations.
# ROLE IN SYSTEM: Enforces data contracts, transfer states, risk bands, and explainability payloads.
# TALKS TO: server/app/api/v1/, server/app/services/risk_engine.py, worker/providers/
from pydantic import BaseModel, Field, model_validator
from typing import List, Optional, Dict, Any
from enum import Enum
import uuid
from datetime import datetime, timezone


class TransferStateEnum(str, Enum):
    INITIATED = "INITIATED"
    VOICE_VERIFIED = "VOICE_VERIFIED"
    RISK_SCORED = "RISK_SCORED"
    COMPLETED = "COMPLETED"
    HELD = "HELD"
    CANCELLED = "CANCELLED"
    FAILED = "FAILED"


class RiskBandEnum(str, Enum):
    PROCEED = "PROCEED"
    SOFT_VERIFY = "SOFT_VERIFY"
    CIRCUIT_BREAK = "CIRCUIT_BREAK"


class TCActionTypeEnum(str, Enum):
    APPROVE = "approve"
    DENY = "deny"


class ConsentPurposeEnum(str, Enum):
    VOICEPRINT_ENROLLMENT = "voiceprint_enrollment"
    ACOUSTIC_ANALYSIS = "acoustic_analysis"
    TRUSTED_CONTACT_ALERTS = "trusted_contact_alerts"


# Bilingual Error Contract
class ErrorDetail(BaseModel):
    code: str
    message: str
    user_message_hi: str
    user_message_en: str
    request_id: str


class ErrorResponse(BaseModel):
    error: ErrorDetail


# Explainability Payload
class SignalContribution(BaseModel):
    signal_id: str
    contribution: int
    max_points: int
    evidence_summary: str


class ExplainabilityPayload(BaseModel):
    total_score: int
    risk_band: RiskBandEnum
    signals: List[SignalContribution]
    computed_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


# Risk Engine Feature Vector Invariant Check
class RiskEngineInput(BaseModel):
    """
    Coercion Risk Engine feature payload.
    Enforces the fairness invariant: zero demographic, age, or gender fields allowed.
    """
    audio_snr_db: float
    clean_speech_duration_sec: float
    transcript: str
    enrolled_embedding: Optional[List[float]] = None
    live_embedding: Optional[List[float]] = None
    baseline_acoustic_profile: Dict[str, Any]
    transaction_amount_paise: int
    user_90_day_max_amount_paise: int
    user_90_day_median_paise: int
    payee_created_hours_ago: float
    hour_of_day_utc: int
    consecutive_transfers_last_10m: int
    language: str = "hi"

    @model_validator(mode="before")
    @classmethod
    def check_no_demographic_fields(cls, values: Any) -> Any:
        if isinstance(values, dict):
            prohibited = ["age", "gender", "sex", "demographic", "caste", "religion", "ethnicity", "dob"]
            for field in prohibited:
                if field in values:
                    raise ValueError(f"Fairness violation: Prohibited demographic field '{field}' cannot enter risk engine")
        return values


# Accounts
class AccountResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    account_number_masked: str
    account_type: str
    currency: str
    balance_paise: int
    opened_at: datetime


# Payees
class PayeeCreate(BaseModel):
    name: str
    masked_account: str
    account_ref: str
    nickname: Optional[str] = None


class PayeeResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    name: str
    masked_account: str
    account_ref: str
    nickname: Optional[str] = None
    verified: bool
    created_at: datetime


# Transfers
class TransferCreateRequest(BaseModel):
    source_account_id: uuid.UUID
    payee_id: uuid.UUID
    amount_paise: int = Field(gt=0)
    transcript: Optional[str] = None
    second_voice_detected: Optional[bool] = None
    voice_stress_score: Optional[int] = None


class TransferResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    source_account_id: uuid.UUID
    payee_id: uuid.UUID
    amount_paise: int
    state: TransferStateEnum
    risk_score: Optional[int] = None
    risk_band: Optional[RiskBandEnum] = None
    explainability: List[SignalContribution] = []
    idempotency_key: str
    cooling_expires_at: Optional[datetime] = None
    created_at: datetime
    final_at: Optional[datetime] = None


# Voice Challenge
class ChallengeGenerateResponse(BaseModel):
    challenge_id: str
    challenge_code: str
    spoken_prompt_en: str
    spoken_prompt_hi: str
    expires_at: datetime


class ChallengeVerifyResponse(BaseModel):
    speaker_match: bool
    digits_match: bool
    live: bool
    similarity: float
    decision: str
    user_message_en: str
    user_message_hi: str


# Voice Enrollment
class PhraseQualityScore(BaseModel):
    phrase_index: int
    snr_db: float
    clean_speech_duration_sec: float
    accepted: bool
    rejection_reason: Optional[str] = None


class VoiceEnrollmentResponse(BaseModel):
    enrollment_id: uuid.UUID
    quality_scores: List[PhraseQualityScore]
    baseline_acoustic_profile: Dict[str, Any]
    all_phrases_accepted: bool
    message_en: str
    message_hi: str


# Trusted Contacts
class TrustedContactInvite(BaseModel):
    trusted_contact_phone: str
    threshold_paise: int = 500000


class TrustedContactResponse(BaseModel):
    id: uuid.UUID
    account_holder_id: uuid.UUID
    trusted_contact_id: uuid.UUID
    trusted_contact_name: Optional[str] = None
    threshold_paise: int
    active: bool
    created_at: datetime


class TCActionRequest(BaseModel):
    attestation: bool
    note: Optional[str] = None
    reason_category: Optional[str] = None


class TCActionResponse(BaseModel):
    id: uuid.UUID
    transfer_id: uuid.UUID
    trusted_contact_id: uuid.UUID
    action: TCActionTypeEnum
    attestation: bool
    attested_at: datetime
    new_transfer_state: TransferStateEnum


# Consents & DPDP
class ConsentGrantRequest(BaseModel):
    purpose: ConsentPurposeEnum
    version: str = "2024.1"


class ConsentResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    purpose: ConsentPurposeEnum
    granted_at: datetime
    revoked_at: Optional[datetime] = None
    version: str


class ErasureResponse(BaseModel):
    user_id: uuid.UUID
    voiceprints_purged: int
    consents_revoked: int
    acoustic_baseline_cleared: bool
    regulatory_financial_records_retained: bool
    completed_at: datetime
    retention_notice: str
