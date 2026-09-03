# PURPOSE: Background asynchronous task runner using ARQ Redis with in-process queue fallback.
# ROLE IN SYSTEM: Executes offloaded speech transcription, embedding computation, and risk jobs.
# TALKS TO: worker/in_process_queue.py, worker/providers/, worker/dsp.py
# DO NOT CONFUSE WITH: server/app/services/sweeper.py (cooling window timeout sweeper)
import asyncio
from typing import Dict, Any, List, Optional
import numpy as np
import structlog
from arq.connections import RedisSettings
from worker.dsp import (
    compute_snr,
    compute_clean_speech_duration,
    compute_vocal_stress,
    detect_second_voice,
    verify_liveness
)
from worker.providers.speaker_provider import speaker_provider, SpeakerEmbeddingProvider
from worker.providers.asr_provider import get_asr_provider, ASRProvider
from worker.in_process_queue import in_process_queue
from server.app.config import settings

logger = structlog.get_logger()


async def process_dsp_job(
    ctx: Dict[Any, Any],
    audio_samples: List[float],
    baseline_profile: Dict[str, Any],
    transcript_override: Optional[str] = None,
    language: str = "hi",
    sample_rate: int = 16000
) -> Dict[str, Any]:
    """
    ARQ worker task: extracts acoustic DSP features, verifies liveness,
    transcribes audio (if needed), and computes speaker embedding.
    Runs off the main FastAPI event loop.
    """
    asr: ASRProvider = ctx.get("asr", get_asr_provider())
    speaker: SpeakerEmbeddingProvider = ctx.get("speaker", speaker_provider)

    audio_arr = np.array(audio_samples, dtype=np.float32)

    # 1. ASR transcription
    if transcript_override:
        transcript = transcript_override
    else:
        transcript = await asr.transcribe(audio_arr, sample_rate, language)

    # 2. Acoustic DSP features
    vocal_stress = compute_vocal_stress(audio_arr, baseline_profile, sample_rate)
    second_voice = detect_second_voice(audio_arr, baseline_profile.get("f0_mean", 150.0), sample_rate)
    liveness = verify_liveness(audio_arr, sample_rate)
    live_embedding = speaker.compute_embedding(audio_arr, sample_rate)

    return {
        "transcript": transcript,
        "vocal_stress": vocal_stress,
        "second_voice": second_voice,
        "liveness": liveness,
        "live_embedding": live_embedding
    }


async def verify_speaker_job(
    ctx: Dict[Any, Any],
    audio_samples: List[float],
    enrolled_embedding: List[float],
    sample_rate: int = 16000
) -> Dict[str, Any]:
    """
    ARQ worker task: verifies speaker identity against enrolled embedding.
    """
    speaker: SpeakerEmbeddingProvider = ctx.get("speaker", speaker_provider)
    audio_arr = np.array(audio_samples, dtype=np.float32)

    live_embedding = speaker.compute_embedding(audio_arr, sample_rate)
    similarity = speaker.compute_similarity(live_embedding, enrolled_embedding)
    is_match = similarity >= settings.SPEAKER_SIMILARITY_THRESHOLD

    return {
        "similarity": round(similarity, 4),
        "is_match": is_match,
        "threshold": settings.SPEAKER_SIMILARITY_THRESHOLD,
        "live_embedding": live_embedding
    }


async def transcribe_audio_job(
    ctx: Dict[Any, Any],
    audio_samples: List[float],
    language: str = "hi",
    sample_rate: int = 16000
) -> str:
    """
    ARQ worker task: transcribes audio chunk.
    """
    asr: ASRProvider = ctx.get("asr", get_asr_provider())
    audio_arr = np.array(audio_samples, dtype=np.float32)
    return await asr.transcribe(audio_arr, sample_rate, language)


async def startup(ctx: Dict[Any, Any]):
    """
    ARQ startup hook: Loads heavy ML models ONCE at worker boot.
    """
    logger.info("Initializing VaniGuard worker models...")
    ctx["asr"] = get_asr_provider()
    ctx["speaker"] = speaker_provider

    # Warm up ASR provider if faster-whisper
    if hasattr(ctx["asr"], "_ensure_initialized"):
        ctx["asr"]._ensure_initialized()

    logger.info("VaniGuard worker models initialized successfully")


async def shutdown(ctx: Dict[Any, Any]):
    """ARQ shutdown hook."""
    logger.info("Shutting down VaniGuard worker")


class WorkerSettings:
    functions = [process_dsp_job, verify_speaker_job, transcribe_audio_job]
    on_startup = startup
    on_shutdown = shutdown
    max_jobs = settings.WORKER_CONCURRENCY

    # Parse redis URL
    redis_url = settings.REDIS_URL
    if redis_url.startswith("redis://"):
        redis_settings = RedisSettings.from_dsn(redis_url)
    else:
        redis_settings = RedisSettings()


# Register fallback in-process queue handlers
in_process_queue.register_handler(
    "process_dsp_job",
    lambda *args, **kwargs: process_dsp_job({"asr": get_asr_provider(), "speaker": speaker_provider}, *args, **kwargs)
)
in_process_queue.register_handler(
    "verify_speaker_job",
    lambda *args, **kwargs: verify_speaker_job({"speaker": speaker_provider}, *args, **kwargs)
)
in_process_queue.register_handler(
    "transcribe_audio_job",
    lambda *args, **kwargs: transcribe_audio_job({"asr": get_asr_provider()}, *args, **kwargs)
)


if __name__ == "__main__":
    from arq import run_worker
    run_worker(WorkerSettings)
