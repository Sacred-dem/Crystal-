from __future__ import annotations

from pydantic import BaseModel, Field
from typing import Any, Dict, List


class ProfileAnalyzeRequest(BaseModel):
    query: str
    sources: List[str] = ["web"]
    scoring_profile: str = "standard_v1"
    signals: Dict[str, float] = Field(default_factory=dict)
    evidence: List[Dict[str, Any]] = Field(default_factory=list)


class ProfileScore(BaseModel):
    authenticity: int
    activity: int
    influence: int
    relevance: int
    risk: int


class EvidenceItem(BaseModel):
    source_type: str
    url: str
    title: str | None = None
    claim: str
    confidence: float


class ProfileAnalyzeResponse(BaseModel):
    target: str
    summary: str
    scores: ProfileScore
    evidence: List[EvidenceItem] = []
    notes: List[str] = []
    source_quality: float = 0.0
    charts: List[Dict[str, Any]] = []
