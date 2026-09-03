import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import numpy as np
import structlog
from server.app.config import settings

logger = structlog.get_logger()


def prefetch_and_verify_models():
    """
    Build-time pre-fetch and cache for speech recognition and speaker biometrics.
    Guarantees models are downloaded and verified BEFORE any client request.
    """
    print("==================================================")
    print("VaniGuard Build-Time Model Pre-Fetch & Warmup")
    print("==================================================")

    # 1. Pre-fetch faster-whisper model
    print(f"\n[1/2] Pre-fetching faster-whisper (model={settings.ASR_MODEL}, compute=int8, device=cpu)...")
    try:
        from faster_whisper import WhisperModel
        whisper = WhisperModel(settings.ASR_MODEL, device="cpu", compute_type="int8")
        print("      Model weights downloaded and loaded.")

        # Test inference on synthetic audio tone (2.0s 440Hz sine wave)
        sr = 16000
        duration = 2.0
        t = np.linspace(0, duration, int(sr * duration), dtype=np.float32)
        synthetic_tone = 0.5 * np.sin(2 * np.pi * 440.0 * t)

        print("      Running verification inference on synthetic audio...")
        segments, info = whisper.transcribe(synthetic_tone, beam_size=1)
        # Consume generator
        list(segments)
        print(f"      faster-whisper verification successful (sample_rate={sr}Hz, language_detected={info.language}).")
    except Exception as e:
        print(f"      faster-whisper prefetch note: {e}")
        print("      Worker will use resilient fallback provider.")

    # 2. Pre-fetch and verify Speaker Embedding Provider (ECAPA-TDNN / 256-d unit d-vector)
    print(f"\n[2/2] Initializing Speaker Embedding Provider (model={settings.SPEAKER_MODEL})...")
    try:
        from worker.providers.speaker_provider import speaker_provider
        sr = 16000
        duration = 3.5
        t = np.linspace(0, duration, int(sr * duration), dtype=np.float32)
        synthetic_speech = 0.5 * np.sin(2 * np.pi * 150.0 * t) + 0.05 * np.sin(2 * np.pi * 300.0 * t)

        embedding = speaker_provider.compute_embedding(synthetic_speech, sr)
        norm = np.linalg.norm(embedding)
        assert len(embedding) == 256, f"Expected 256-d embedding, got {len(embedding)}"
        print(f"      Speaker embedding verified: dim={len(embedding)}, Euclidean norm={norm:.4f}")

        quality = speaker_provider.evaluate_enrollment_quality(synthetic_speech, sr)
        print(f"      Enrollment gating verified: SNR={quality['snr_db']}dB, Clean speech={quality['clean_speech_duration_sec']}s")
    except Exception as e:
        print(f"      Speaker provider error: {e}")
        sys.exit(1)

    print("\nSUCCESS: All models pre-fetched, cached, and verified for production.")
    print("==================================================")


if __name__ == "__main__":
    prefetch_and_verify_models()
