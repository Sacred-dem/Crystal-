from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path


class PiperSpeaker:
    def __init__(self, model_path: str | None = None, config_path: str | None = None):
        self.model_path = model_path or os.getenv("CRYSTAL_PIPER_MODEL", "")
        self.config_path = config_path or os.getenv("CRYSTAL_PIPER_CONFIG", "")

    def _speak_with_piper(self, text: str) -> bytes:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            output_path = tmpdir_path / "output.wav"

            command = [
                "piper",
                "--model",
                self.model_path,
                "--output_file",
                str(output_path),
            ]
            if self.config_path:
                command.extend(["--config", self.config_path])

            subprocess.run(
                command,
                input=text.encode("utf-8"),
                check=True,
            )
            return output_path.read_bytes()

    def _speak_with_espeak(self, text: str) -> bytes:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            output_path = tmpdir_path / "output.wav"
            subprocess.run(
                ["espeak-ng", "-w", str(output_path), text],
                check=True,
            )
            return output_path.read_bytes()

    def synthesize_to_wav(self, text: str) -> bytes:
        if self.model_path and shutil.which("piper"):
            return self._speak_with_piper(text)
        if shutil.which("espeak-ng"):
            return self._speak_with_espeak(text)
        raise RuntimeError(
            "No voice engine is available. Install piper or ensure espeak-ng is present in the container."
        )
