from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import Iterator

from app.core.config import settings


SCHEMA_PATH = Path(__file__).resolve().parents[1] / "migrations" / "001_init.sql"


def get_connection() -> sqlite3.Connection:
    db_path = Path(settings.db_path)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db() -> None:
    with get_connection() as conn:
        conn.executescript(SCHEMA_PATH.read_text())
        conn.commit()


def iter_rows(query: str, params: tuple = ()) -> Iterator[sqlite3.Row]:
    with get_connection() as conn:
        cursor = conn.execute(query, params)
        yield from cursor.fetchall()
