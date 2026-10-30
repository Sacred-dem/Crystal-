from __future__ import annotations

from typing import Dict


def _bounded(value: float) -> int:
    return max(0, min(100, round(value)))


def score_profile(signals: Dict[str, float]) -> dict:
    verified = signals.get("verified", 0.0)
    recency = signals.get("recency", 0.0)
    activity = signals.get("activity", 0.0)
    reach = signals.get("reach", 0.0)
    consistency = signals.get("consistency", 0.0)
    relevance = signals.get("relevance", 0.0)
    risk_flags = signals.get("risk_flags", 0.0)
    source_quality = signals.get("source_quality", 0.5)

    authenticity = _bounded((verified * 40) + (consistency * 35) + (source_quality * 25))
    activity_score = _bounded((recency * 50) + (activity * 50))
    influence = _bounded((reach * 60) + (activity * 20) + (source_quality * 20))
    relevance_score = _bounded(relevance * 100)
    risk = _bounded((risk_flags * 70) + ((1 - source_quality) * 30))

    return {
        "authenticity": authenticity,
        "activity": activity_score,
        "influence": influence,
        "relevance": relevance_score,
        "risk": risk,
        "source_quality": round(source_quality, 2),
    }
