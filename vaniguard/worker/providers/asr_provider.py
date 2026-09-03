from abc import ABC, abstractmethod
from typing import Optional
import io
import wave
import numpy as np
import httpx
from server.app.config import settings
from bench.bench_challenge_verification import ConstrainedDigitGrammarDecoder


class ASRProvider(ABC):
    """
    Abstract interface for Automatic Speech Recognition.
    Supports Hindi and English with pluggable backend implementations.
    """
    @abstractmethod
    async def transcribe(self, audio: np.ndarray, sample_rate: int = 16000, language: str = "hi") -> str:
        """Transcribe audio chunk into text."""
        pass

    @abstractmethod
    async def transcribe_digits(self, audio: np.ndarray, sample_rate: int = 16000) -> str:
        """Constrained transcription for 6-digit challenge code."""
        pass


class FasterWhisperASRProvider(ASRProvider):
    """
    Primary on-premises ASR engine using faster-whisper (small, int8 quantization on CPU).
    Loads model once on worker startup.
    """
    def __init__(self, model_size: str = settings.ASR_MODEL, compute_type: str = "int8"):
        self.model_size = model_size
        self.compute_type = compute_type
        self._model = None
        self._initialized = False

    def _ensure_initialized(self):
        if not self._initialized:
            try:
                from faster_whisper import WhisperModel
                self._model = WhisperModel(self.model_size, device="cpu", compute_type=self.compute_type)
                self._initialized = True
            except Exception:
                self._model = None
                self._initialized = True

    async def transcribe(self, audio: np.ndarray, sample_rate: int = 16000, language: str = "hi") -> str:
        self._ensure_initialized()
        if self._model is not None:
            segments, _ = self._model.transcribe(audio, language=language, beam_size=2)
            text = " ".join([segment.text for segment in segments]).strip()
            return text

        # Fallback to Groq if configured
        if settings.ASR_PROVIDER == "groq_api" and settings.ASR_API_KEY:
            groq = GroqASRProvider()
            return await groq.transcribe(audio, sample_rate, language)

        return ""

    async def transcribe_digits(self, audio: np.ndarray, sample_rate: int = 16000) -> str:
        raw_text = await self.transcribe(audio, sample_rate)
        return ConstrainedDigitGrammarDecoder.decode_spoken_digits(raw_text)


class GroqASRProvider(ASRProvider):
    """
    High-speed Groq API fallback ASR provider (whisper-large-v3-turbo).
    Active when ASR_PROVIDER=groq_api and ASR_API_KEY is configured.
    """
    def __init__(self, api_key: Optional[str] = settings.ASR_API_KEY):
        self.api_key = api_key
        self.endpoint = "https://api.groq.com/openai/v1/audio/transcriptions"

    async def transcribe(self, audio: np.ndarray, sample_rate: int = 16000, language: str = "hi") -> str:
        if not self.api_key:
            return ""

        # Format audio chunk as 16-bit PCM wav
        pcm16 = (np.clip(audio, -1.0, 1.0) * 32767).astype(np.int16)
        buffer = io.BytesIO()
        with wave.open(buffer, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(pcm16.tobytes())
        wav_bytes = buffer.getvalue()

        headers = {"Authorization": f"Bearer {self.api_key}"}
        files = {"file": ("audio.wav", wav_bytes, "audio/wav")}
        data = {"model": "whisper-large-v3-turbo", "language": language}

        try:
            async with httpx.AsyncClient(timeout=4.0) as client:
                resp = await client.post(self.endpoint, headers=headers, files=files, data=data)
                if resp.status_code == 200:
                    return resp.json().get("text", "").strip()
        except Exception:
            pass
        return ""

    async def transcribe_digits(self, audio: np.ndarray, sample_rate: int = 16000) -> str:
        raw_text = await self.transcribe(audio, sample_rate)
        return ConstrainedDigitGrammarDecoder.decode_spoken_digits(raw_text)


def get_asr_provider() -> ASRProvider:
    if settings.ASR_PROVIDER == "groq_api" and settings.ASR_API_KEY:
        return GroqASRProvider()
    return FasterWhisperASRProvider()
