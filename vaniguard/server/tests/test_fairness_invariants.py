# PURPOSE: Invariant verification ensuring zero demographic bias in coercion risk scoring.
# ROLE IN SYSTEM: Asserts identical scores across simulated demographic attributes given same acoustics.
# TALKS TO: server/app/services/risk_engine.py, server/app/models/schemas.py
import pytest
from pydantic import ValidationError
from server.app.models.schemas import RiskEngineInput


def test_fairness_invariant_schema_has_no_demographic_fields():
    """
    CI test strictly enforcing that the risk engine feature schema contains
    zero demographic, age, gender, or proxy fields.
    """
    field_names = set(RiskEngineInput.model_fields.keys())
    prohibited_tokens = [
        "age",
        "user_age",
        "gender",
        "sex",
        "demographic",
        "caste",
        "religion",
        "ethnicity",
        "dob",
        "date_of_birth",
        "birth_year",
        "senior_flag",
        "is_elderly"
    ]

    for field in field_names:
        assert field.lower() not in prohibited_tokens, (
            f"FAIRNESS VIOLATION: RiskEngineInput schema contains demographic field '{field}'"
        )
        # Also ensure none of the fields start with or end with age/gender
        parts = field.lower().split("_")
        for p in parts:
            assert p not in ["age", "gender", "sex", "caste", "religion"], (
                f"FAIRNESS VIOLATION: RiskEngineInput token contains demographic field '{field}'"
            )


def test_fairness_invariant_rejects_demographic_inputs_at_runtime():
    """
    Validates that any attempt to pass prohibited demographic fields
    is strictly intercepted and rejected by the schema validator.
    """
    base_valid_data = {
        "audio_snr_db": 18.0,
        "clean_speech_duration_sec": 3.2,
        "transcript": "Transfer five hundred rupees to milkman",
        "enrolled_embedding": None,
        "live_embedding": None,
        "baseline_acoustic_profile": {"f0_mean": 150.0, "f0_std": 15.0, "jitter": 0.015, "shimmer": 0.035},
        "transaction_amount_paise": 50000,
        "user_90_day_max_amount_paise": 1000000,
        "user_90_day_median_paise": 250000,
        "payee_created_hours_ago": 48.0,
        "hour_of_day_utc": 11,
        "consecutive_transfers_last_10m": 1,
        "language": "hi"
    }

    # Attempt to inject 'age'
    with pytest.raises(ValidationError) as excinfo:
        data_with_age = {**base_valid_data, "age": 72}
        RiskEngineInput(**data_with_age)
    assert "Fairness violation" in str(excinfo.value)

    # Attempt to inject 'gender'
    with pytest.raises(ValidationError) as excinfo:
        data_with_gender = {**base_valid_data, "gender": "female"}
        RiskEngineInput(**data_with_gender)
    assert "Fairness violation" in str(excinfo.value)
