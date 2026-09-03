import sys
import json
from typing import List, Optional, Union
from pydantic_settings import BaseSettings
from pydantic import Field, ConfigDict, field_validator
import structlog

logger = structlog.get_logger()


def key_fingerprint(val: Optional[str]) -> str:
    """Returns only the first 6 characters of a secret key for safe logging."""
    if not val:
        return "<not-set>"
    return f"{val[:6]}..."


class Settings(BaseSettings):
    # Supabase Infrastructure
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str
    SUPABASE_SERVICE_ROLE_KEY: str
    DATABASE_URL: str

    # Cryptography
    KMS_MASTER_KEY: str
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"

    # API Server Configuration
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    ENVIRONMENT: str = "production"
    CORS_ORIGINS: Union[List[str], str] = ["*"]

    # Redis Task Queue
    REDIS_URL: str = "redis://localhost:6379/0"
    USE_IN_PROCESS_QUEUE: bool = True
    WORKER_CONCURRENCY: int = 4

    # Audio DSP & Streaming
    AUDIO_SAMPLE_RATE: int = 16000
    AUDIO_FRAME_MS: int = 100

    # Speech Recognition & Speaker Biometrics
    ASR_PROVIDER: str = "faster_whisper"
    ASR_MODEL: str = "small"
    ASR_API_KEY: Optional[str] = ""
    SPEAKER_MODEL: str = "ecapa_tdnn"
    SPEAKER_SIMILARITY_THRESHOLD: float = 0.68
    ENROLLMENT_MIN_SPEECH_SEC: float = 3.0
    ENROLLMENT_MIN_SNR_DB: float = 12.0

    # Risk Engine Configuration
    RISK_SIGNAL_CONFIG_VERSION: str = "v1"
    CIRCUIT_BREAK_JITTER_RANGE: int = 5
    COOLING_WINDOW_MINUTES: int = 30
    SWEEPER_INTERVAL_SECONDS: int = 15

    # Observability
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "json"

    model_config = ConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def parse_cors(cls, v):
        if isinstance(v, str):
            try:
                return json.loads(v)
            except Exception:
                return [origin.strip() for origin in v.split(",") if origin.strip()]
        return v

    @field_validator("SUPABASE_URL")
    @classmethod
    def validate_supabase_url(cls, v: str) -> str:
        if not v or not v.strip() or "your-project" in v:
            err_msg = (
                "Fatal configuration error: SUPABASE_URL is missing or invalid. "
                "घातक कॉन्फ़िगरेशन त्रुटि: SUPABASE_URL अनुपलब्ध या अमान्य है।"
            )
            raise ValueError(err_msg)
        return v.strip()

    @field_validator("SUPABASE_SERVICE_ROLE_KEY")
    @classmethod
    def validate_service_role_key(cls, v: str) -> str:
        if not v or not v.strip() or "secret_key" in v:
            err_msg = (
                "Fatal configuration error: SUPABASE_SERVICE_ROLE_KEY is missing or invalid. "
                "घातक कॉन्फ़िगरेशन त्रुटि: SUPABASE_SERVICE_ROLE_KEY अनुपलब्ध या अमान्य है।"
            )
            raise ValueError(err_msg)
        return v.strip()


def load_settings() -> Settings:
    try:
        cfg = Settings()
        # Safe logging of key fingerprints only
        logger.info(
            "VaniGuard configuration loaded successfully",
            supabase_url=cfg.SUPABASE_URL,
            service_role_fingerprint=key_fingerprint(cfg.SUPABASE_SERVICE_ROLE_KEY),
            anon_key_fingerprint=key_fingerprint(cfg.SUPABASE_ANON_KEY),
            kms_fingerprint=key_fingerprint(cfg.KMS_MASTER_KEY),
            environment=cfg.ENVIRONMENT,
            asr_provider=cfg.ASR_PROVIDER,
            speaker_model=cfg.SPEAKER_MODEL
        )
        return cfg
    except Exception as e:
        sys.stderr.write(
            f"\n[FATAL STARTUP ERROR / घातक स्टार्टअप त्रुटि]: {e}\n"
            f"VaniGuard cannot start without valid SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env\n\n"
        )
        sys.exit(1)


settings = load_settings()
