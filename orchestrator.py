from __future__ import annotations

import re

from app.chat.repository import ChatRepository
from app.memory.models import MemoryItem
from app.memory.repository import MemoryRepository
from app.schemas.chat import ChatRequest, ChatResponse


class Orchestrator:
    def __init__(self, memory_repo: MemoryRepository | None = None, chat_repo: ChatRepository | None = None):
        self.memory_repo = memory_repo or MemoryRepository()
        self.chat_repo = chat_repo or ChatRepository()

    def _should_store_memory(self, message: str) -> tuple[bool, str | None]:
        text = message.strip()
        remember_patterns = [
            r"^remember that (.+)$",
            r"^remember (.+)$",
            r"^keep in mind (.+)$",
            r"^my preference is (.+)$",
            r"^i prefer (.+)$",
        ]
        for pattern in remember_patterns:
            match = re.match(pattern, text, flags=re.IGNORECASE)
            if match:
                return True, match.group(1).strip()
        return False, None

    def respond(self, payload: ChatRequest) -> ChatResponse:
        self.chat_repo.ensure_session(payload.session_id, payload.user_id, mode=payload.mode if payload.mode != "auto" else "hybrid")
        self.chat_repo.save_message(payload.session_id, role="user", content=payload.message, format=payload.response_format)

        should_store, memory_text = self._should_store_memory(payload.message)
        stored = []

        if should_store and memory_text:
            item = MemoryItem.new(
                user_id=payload.user_id,
                kind="preference",
                content=memory_text,
                confidence=0.92,
            )
            self.memory_repo.save(item)
            stored.append({"id": item.id, "kind": item.kind, "content": item.content})

        recalls = self.memory_repo.recent(payload.user_id, limit=3)
        recall_text = ""
        if recalls:
            joined = "; ".join([m["content"] for m in recalls])
            recall_text = f" I’m carrying a few notes for you: {joined}."

        assistant_text = (
            f"Crystal here. I heard: {payload.message}."
            f" I’m ready to help with the next step.{recall_text}"
        )

        assistant_message_id = self.chat_repo.save_message(payload.session_id, role="assistant", content=assistant_text, format="text")

        return ChatResponse(
            message_id=assistant_message_id,
            assistant_text=assistant_text,
            mode_used=payload.mode if payload.mode != "auto" else "offline",
            artifacts=[],
            citations=[],
            memory_updates=stored,
            warnings=[],
        )
