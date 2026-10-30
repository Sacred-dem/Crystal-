from __future__ import annotations

from pydantic import BaseModel
from typing import List, Optional


class Artifact(BaseModel):
    type: str
    id: str
    title: Optional[str] = None


class ChatRequest(BaseModel):
    session_id: str
    message: str
    user_id: str = "default"
    mode: str = "auto"
    response_format: str = "text"


class ChatResponse(BaseModel):
    message_id: str
    assistant_text: str
    mode_used: str
    artifacts: List[Artifact] = []
    citations: List[dict] = []
    memory_updates: List[dict] = []
    warnings: List[str] = []
