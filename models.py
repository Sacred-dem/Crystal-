from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional
import uuid


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class MemoryItem:
    id: str
    user_id: str
    kind: str
    content: str
    confidence: float = 1.0
    source_message_id: Optional[str] = None
    created_at: str = field(default_factory=now_iso)
    updated_at: str = field(default_factory=now_iso)

    @staticmethod
    def new(user_id: str, kind: str, content: str, confidence: float = 1.0, source_message_id: str | None = None) -> "MemoryItem":
        now = now_iso()
        return MemoryItem(
            id=f"mem_{uuid.uuid4().hex[:12]}",
            user_id=user_id,
            kind=kind,
            content=content,
            confidence=confidence,
            source_message_id=source_message_id,
            created_at=now,
            updated_at=now,
        )
