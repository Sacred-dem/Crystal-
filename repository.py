from __future__ import annotations

import uuid
from datetime import datetime, timezone

from app.core.database import get_connection


class ChatRepository:
    def ensure_session(self, session_id: str, user_id: str, mode: str = "hybrid") -> None:
        now = datetime.now(timezone.utc).isoformat()
        with get_connection() as conn:
            conn.execute(
                """
                INSERT OR IGNORE INTO sessions (id, user_id, mode, summary, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (session_id, user_id, mode, None, now, now),
            )
            conn.commit()

    def save_message(self, session_id: str, role: str, content: str, format: str = "text", metadata_json: str | None = None) -> str:
        now = datetime.now(timezone.utc).isoformat()
        message_id = f"msg_{uuid.uuid4().hex[:16]}"
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO messages (id, session_id, role, content, format, token_count, metadata_json, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (message_id, session_id, role, content, format, 0, metadata_json, now),
            )
            conn.commit()
        return message_id

    def recent_messages(self, session_id: str, limit: int = 10) -> list[dict]:
        with get_connection() as conn:
            cursor = conn.execute(
                """
                SELECT id, session_id, role, content, format, token_count, metadata_json, created_at
                FROM messages
                WHERE session_id = ?
                ORDER BY created_at DESC
                LIMIT ?
                """,
                (session_id, limit),
            )
            rows = cursor.fetchall()
        return [dict(row) for row in rows]
