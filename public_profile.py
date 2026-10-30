from __future__ import annotations

import uuid

from app.analysis.scoring import score_profile
from app.schemas.profile import EvidenceItem, ProfileAnalyzeResponse, ProfileScore


def normalize_evidence(raw_evidence: list[dict]) -> list[EvidenceItem]:
    items: list[EvidenceItem] = []
    for row in raw_evidence:
        items.append(
            EvidenceItem(
                source_type=row.get("source_type", "web"),
                url=row.get("url", ""),
                title=row.get("title"),
                claim=row.get("claim", ""),
                confidence=float(row.get("confidence", 0.5)),
            )
        )
    return items


def build_public_profile_report(query: str, signals: dict, evidence: list[dict], scoring_profile: str = "standard_v1") -> ProfileAnalyzeResponse:
    scores = score_profile(signals)
    normalized = normalize_evidence(evidence)
    source_quality = scores.pop("source_quality")

    summary = (
        f"Crystal analyzed the public profile for '{query}'. "
        f"This report uses public signals only and labels uncertainty where evidence is thin."
    )

    notes = [
        "Public-data only",
        "Scores are estimates, not facts",
        f"Scoring profile: {scoring_profile}",
    ]

    return ProfileAnalyzeResponse(
        target=query,
        summary=summary,
        scores=ProfileScore(**scores),
        evidence=normalized,
        notes=notes,
        source_quality=source_quality,
        charts=[{"type": "radar", "id": f"radar_{uuid.uuid4().hex[:8]}"}],
    )
