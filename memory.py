from fastapi import APIRouter
from pydantic import BaseModel
from typing import Any, Dict

from app.memory.models import MemoryItem
from app.memory.repository import MemoryRepository

router = APIRouter()
memory_repo = MemoryRepository()


class MemoryRequest(BaseModel):
    user_id: str
    kind: str
    content: str
    confidence: float = 1.0
    metadata: Dict[str, Any] = {}


@router.post("/remember")
def remember(payload: MemoryRequest):
    item = MemoryItem.new(
        user_id=payload.user_id,
        kind=payload.kind,
        content=payload.content,
        confidence=payload.confidence,
    )
    memory_repo.save(item)
    return {"stored": True, "item": {"id": item.id, **payload.model_dump()}}


@router.get("/search")
def search(q: str, user_id: str | None = None, limit: int = 5):
    if not user_id:
        return {"query": q, "user_id": user_id, "limit": limit, "results": []}
    results = memory_repo.search(user_id=user_id, query=q, limit=limit)
    return {"query": q, "user_id": user_id, "limit": limit, "results": results}
