from __future__ import annotations

import os
import tempfile
from typing import Any


class WhisperTranscriber:
    def __init__(self, model_name: str | None = None):
        self.model_name = model_name or os.getenv("CRYSTAL_WHISPER_MODEL", "base")
        self._model = None

    @property
    def model(self):
        if self._model is None:
            try:
                from faster_whisper import WhisperModel
            except Exception as exc:  # pragma: no cover - import guard
                raise RuntimeError(
                    "faster-whisper is not installed. Install backend dependencies to enable voice transcription."
                ) from exc
            self._model = WhisperModel(self.model_name, device="cpu", compute_type="int8")
        return self._model

    def transcribe_bytes(self, audio_bytes: bytes, language: str | None = None) -> dict[str, Any]:
        with tempfile.NamedTemporaryFile(suffix=".webm", delete=True) as audio_file:
            audio_file.write(audio_bytes)
            audio_file.flush()
            segments, info = self.model.transcribe(audio_file.name, language=language)
            text = " ".join(segment.text.strip() for segment in segments).strip()
            return {
                "text": text,
                "language": getattr(info, "language", language or "unknown"),
                "confidence": float(getattr(info, "probability", 0.0)),
            }
