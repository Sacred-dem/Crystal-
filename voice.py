from __future__ import annotations

from fastapi import APIRouter, File, UploadFile
from fastapi.responses import Response
from pydantic import BaseModel

from app.voice.stt import WhisperTranscriber
from app.voice.tts import PiperSpeaker

router = APIRouter()
transcriber = WhisperTranscriber()
speaker = PiperSpeaker()


class SynthesizeRequest(BaseModel):
    text: str
    voice: str = "default"
    style: str = "warm"


@router.post("/transcribe")
async def transcribe(audio: UploadFile = File(...)):
    data = await audio.read()
    result = transcriber.transcribe_bytes(data)
    return result


@router.post("/synthesize")
def synthesize(payload: SynthesizeRequest):
    wav_bytes = speaker.synthesize_to_wav(payload.text)
    return Response(content=wav_bytes, media_type="audio/wav")
