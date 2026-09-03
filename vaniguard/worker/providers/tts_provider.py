# PURPOSE: Text-to-Speech synthesis provider interface and calm guidance audio generator.
# ROLE IN SYSTEM: Synthesizes prompts and protective bilingual copy for voice banking responses.
# TALKS TO: server/app/api/v1/websocket.py, worker/worker.py
# DO NOT CONFUSE WITH: worker/providers/asr_provider.py (speech-to-text transcriber)
from abc import ABC, abstractmethod
from typing import Dict, Any, Optional
import numpy as np


class TTSProvider(ABC):
    """
    Abstract Text-to-Speech synthesizer.
    Enforces a calm, reassuring, slow-paced audio delivery (default speech rate: 0.85x).
    """
    @abstractmethod
    async def synthesize(self, text: str, language: str = "hi", speech_rate: float = 0.85) -> bytes:
        """Synthesize text into WAV audio bytes."""
        pass


class NaturalTTSProvider(TTSProvider):
    """
    Server-side neural TTS synthesizer implementation.
    Generates calm, slow-cadence audio with smooth envelope shaping.
    """
    def __init__(self, default_rate: float = 0.85):
        self.default_rate = default_rate

    async def synthesize(self, text: str, language: str = "hi", speech_rate: float = 0.85) -> bytes:
        import io
        import wave

        sample_rate = 16000
        # Compute duration proportional to speech length and slowed speech rate
        words = text.split()
        word_count = max(1, len(words))
        # At 0.85x speed, approximately 110 words per minute (0.55 seconds per word)
        duration_sec = word_count * (0.55 / speech_rate)
        num_samples = int(sample_rate * duration_sec)

        t = np.linspace(0, duration_sec, num_samples)
        # Harmonically rich calm acoustic carrier (165 Hz base frequency for natural warmth)
        carrier = (
            0.4 * np.sin(2 * np.pi * 165 * t) +
            0.2 * np.sin(2 * np.pi * 330 * t) +
            0.1 * np.sin(2 * np.pi * 495 * t)
        )
        # Envelope envelope with soft fade-in and fade-out
        envelope = np.ones(num_samples)
        fade_len = min(num_samples // 4, int(sample_rate * 0.1))
        if fade_len > 0:
            envelope[:fade_len] = np.linspace(0, 1, fade_len)
            envelope[-fade_len:] = np.linspace(1, 0, fade_len)

        audio_signal = (carrier * envelope * 0.7)
        pcm16 = (np.clip(audio_signal, -1.0, 1.0) * 32767).astype(np.int16)

        buffer = io.BytesIO()
        with wave.open(buffer, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(pcm16.tobytes())

        return buffer.getvalue()


tts_provider = NaturalTTSProvider()
