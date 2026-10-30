from fastapi.testclient import TestClient

from app.core import config
from app.core.database import init_db
from app.main import app


def test_health_endpoint(tmp_path):
    config.settings.db_path = str(tmp_path / "crystal.db")
    init_db()
    client = TestClient(app)

    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_chat_memory_persistence(tmp_path):
    config.settings.db_path = str(tmp_path / "crystal.db")
    init_db()
    client = TestClient(app)

    response = client.post(
        "/chat/message",
        json={
            "session_id": "sess_test",
            "user_id": "user_test",
            "message": "Remember that I like short answers",
            "mode": "auto",
            "response_format": "text",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["memory_updates"]
    assert "short answers" in data["assistant_text"] or "short answers" in data["memory_updates"][0]["content"]


def test_profile_analysis_scores(tmp_path):
    config.settings.db_path = str(tmp_path / "crystal.db")
    init_db()
    client = TestClient(app)

    response = client.post(
        "/profile/analyze",
        json={
            "query": "example public person",
            "signals": {
                "verified": 0.8,
                "recency": 0.7,
                "activity": 0.6,
                "reach": 0.5,
                "consistency": 0.9,
                "relevance": 0.85,
                "risk_flags": 0.1,
                "source_quality": 0.8,
            },
            "evidence": [
                {
                    "source_type": "web",
                    "url": "https://example.com",
                    "title": "Public Profile",
                    "claim": "Visible public signal",
                    "confidence": 0.9,
                }
            ],
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["scores"]["authenticity"] >= 0
    assert data["scores"]["risk"] >= 0
