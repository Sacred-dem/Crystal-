#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-crystal}"
mkdir -p "$ROOT"
cd "$ROOT"

mkdir -p \
  .github/workflows \
  apps/desktop \
  apps/desktop/src \
  apps/desktop/src/components \
  apps/desktop/src/services \
  apps/desktop/src/types \
  backend \
  backend/app \
  backend/app/analysis \
  backend/app/api \
  backend/app/chat \
  backend/app/core \
  backend/app/memory \
  backend/app/migrations \
  backend/app/orchestration \
  backend/app/schemas \
  backend/app/voice \
  backend/tests \
  docs \
  shared/contracts \
  voice-models

cat > README.md <<'EOF'
# Crystal

Crystal is a hybrid AI companion starter codebase.

**Owner:** Mr Sacred
**Project name:** Crystal
**Lineage:** Built for Sacred / SHPERE

## Docker quick start
From the repository root:

```bash
docker compose up --build
```

Then open:
- Crystal local domain: https://crystal.localhost
- Backend health: https://crystal.localhost/api/health

## Voice setup
Crystal uses:
- `faster-whisper` for speech-to-text
- `piper` when a model is mounted, with `espeak-ng` as a local fallback
- browser microphone permission allowed in the frontend

Set these environment variables for the best voice quality:
- `CRYSTAL_WHISPER_MODEL=base`
- `CRYSTAL_PIPER_MODEL=/models/en_US-amy-medium.onnx`
- `CRYSTAL_PIPER_CONFIG=/models/en_US-amy-medium.onnx.json`

If you want Piper, put the model files in `./voice-models/` so they mount into the container at `/models`.
If no Piper model is mounted, the app still speaks with the local `espeak-ng` fallback.

## Structure
- `backend/` — FastAPI service
- `apps/desktop/` — React + TypeScript UI
- `shared/` — shared contracts

## GitHub Actions deployment
This repo includes a VPS deployment workflow at `.github/workflows/deploy-vps.yml`.

### Required secrets
- `SSH_HOST`
- `SSH_USER`
- `SSH_PORT`
- `SSH_PRIVATE_KEY`
- `DEPLOY_PATH`

### Server requirements
- Docker installed
- Docker Compose installed
- `rsync` installed
- the deploy directory already created and writable by `SSH_USER`
- optional Piper model files placed in `<DEPLOY_PATH>/voice-models/` (the deploy never deletes them)

Each push to `main` syncs the code to the server with rsync and then runs the production compose command.

### Production launch command
On the server, the production stack runs with:
```bash
docker compose -f docker-compose.prod.yml up -d --build
```

If you do not have a domain yet, Caddy serves the app on port 80, so you can open it by the server IP.
If you later add a real domain, you can update the Caddyfile to use that hostname and TLS.

## Run idea
1. Start the backend API.
2. Start the desktop app.
3. Open the local domain and send a chat message.
4. Use the voice panel to record, transcribe, reply, and speak.

This repository is a starter scaffold for building Crystal into a local-first, voice-enabled AI companion.

## Publish to GitHub
```bash
cd crystal
git init -b main
git add .
git commit -m "Initial Crystal scaffold"
git remote add origin https://github.com/<your-user>/crystal.git
git push -u origin main
```
Then add the five secrets above under **Settings -> Secrets and variables -> Actions**.
The `crystal-ci` workflow runs on every push and pull request. The `crystal-deploy-vps` workflow runs on pushes to `main`.

## Notes
- Browsers only allow microphone access on `localhost`/`*.localhost` or over HTTPS. When serving the production stack by bare server IP over plain HTTP, the voice panel cannot record until you add a real domain with TLS.
- `https://crystal.localhost` uses Caddy's internal CA. Your browser may show a certificate warning the first time.
- Backend tests: `cd backend && pip install -e ".[test]" && pytest -q`

EOF

cat > .env.example <<'EOF'
CRYSTAL_ENV=development
CRYSTAL_MODE=hybrid
CRYSTAL_API_HOST=0.0.0.0
CRYSTAL_API_PORT=8000
CRYSTAL_DB_PATH=./data/crystal.db
CRYSTAL_VECTOR_PATH=./data/vector
VITE_API_URL=http://localhost:8000
EOF

cat > .dockerignore <<'EOF'
.git
node_modules
**/node_modules
**/__pycache__
**/*.pyc
backend/data
crystal.db
EOF

cat > .gitignore <<'EOF'
# Python
__pycache__/
*.pyc
.pytest_cache/
.venv/
*.egg-info/

# Node
node_modules/
dist/

# Local data and secrets
.env
data/
backend/data/
*.db

# Voice models are large; keep only the README
voice-models/*
!voice-models/README.md

# OS / editor
.DS_Store
.idea/
.vscode/

EOF

cat > docker-compose.yml <<'EOF'
services:
  backend:
    build:
      context: ./backend
    environment:
      - CRYSTAL_ENV=development
      - CRYSTAL_MODE=hybrid
      - CRYSTAL_DB_PATH=/app/data/crystal.db
      - CRYSTAL_VECTOR_PATH=/app/data/vector
      - CRYSTAL_WHISPER_MODEL=base
      - CRYSTAL_PIPER_MODEL=/models/en_US-amy-medium.onnx
      - CRYSTAL_PIPER_CONFIG=/models/en_US-amy-medium.onnx.json
    volumes:
      - crystal_data:/app/data
      - ./voice-models:/models

  frontend:
    build:
      context: ./apps/desktop
    environment:
      - VITE_API_URL=/api
    depends_on:
      - backend

  caddy:
    image: caddy:2.8-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - backend
      - frontend

volumes:
  crystal_data:
  caddy_data:
  caddy_config:
EOF

cat > docker-compose.prod.yml <<'EOF'
services:
  backend:
    build:
      context: ./backend
    environment:
      - CRYSTAL_ENV=production
      - CRYSTAL_MODE=hybrid
      - CRYSTAL_DB_PATH=/app/data/crystal.db
      - CRYSTAL_VECTOR_PATH=/app/data/vector
      - CRYSTAL_WHISPER_MODEL=base
      - CRYSTAL_PIPER_MODEL=/models/en_US-amy-medium.onnx
      - CRYSTAL_PIPER_CONFIG=/models/en_US-amy-medium.onnx.json
    volumes:
      - crystal_data:/app/data
      - ./voice-models:/models
    restart: unless-stopped

  frontend:
    build:
      context: ./apps/desktop
      dockerfile: Dockerfile.prod
    depends_on:
      - backend
    restart: unless-stopped

  caddy:
    image: caddy:2.8-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile.prod:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - backend
      - frontend
    restart: unless-stopped

volumes:
  crystal_data:
  caddy_data:
  caddy_config:
EOF

cat > Caddyfile <<'EOF'
crystal.localhost {
  tls internal
  encode gzip zstd

  handle_path /api/* {
    reverse_proxy backend:8000
  }

  handle {
    reverse_proxy frontend:5173
  }
}
EOF

cat > Caddyfile.prod <<'EOF'
:80 {
  encode gzip zstd

  handle_path /api/* {
    reverse_proxy backend:8000
  }

  handle {
    reverse_proxy frontend:80
  }
}
EOF

cat > .github/workflows/ci.yml <<'EOF'
name: crystal-ci

on:
  push:
  pull_request:

jobs:
  backend-test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - name: Install backend dependencies
        run: |
          python -m pip install --upgrade pip
          pip install fastapi "uvicorn[standard]" pydantic python-multipart faster-whisper pytest httpx
      - name: Run backend tests
        env:
          CRYSTAL_DB_PATH: /tmp/crystal-test.db
        run: pytest -q

  frontend-build:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: apps/desktop
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Install frontend dependencies
        run: npm install
      - name: Build frontend
        run: npm run build
EOF

cat > .github/workflows/deploy-vps.yml <<'EOF'
name: crystal-deploy-vps

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    env:
      SSH_HOST: ${{ secrets.SSH_HOST }}
      SSH_USER: ${{ secrets.SSH_USER }}
      SSH_PORT: ${{ secrets.SSH_PORT }}
      DEPLOY_PATH: ${{ secrets.DEPLOY_PATH }}
    steps:
      - uses: actions/checkout@v4

      - name: Install SSH key
        uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}

      - name: Add server to known hosts
        run: |
          mkdir -p ~/.ssh
          ssh-keyscan -p "$SSH_PORT" -H "$SSH_HOST" >> ~/.ssh/known_hosts

      - name: Sync code to server
        run: |
          rsync -az --delete \
            --exclude='.git' \
            --exclude='.github' \
            --exclude='.env' \
            --include='voice-models/README.md' \
            --exclude='voice-models/*' \
            -e "ssh -p $SSH_PORT" \
            ./ "$SSH_USER@$SSH_HOST:$DEPLOY_PATH/"

      - name: Deploy on server
        run: |
          ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "cd '$DEPLOY_PATH' && docker compose -f docker-compose.prod.yml up -d --build"
EOF

cat > voice-models/README.md <<'EOF'
# Voice models

Place your Piper voice model files here if you want Crystal to speak with Piper instead of the local fallback.

Example files:
- `en_US-amy-medium.onnx`
- `en_US-amy-medium.onnx.json`

These files are intentionally not committed to git.
EOF

cat > backend/pyproject.toml <<'EOF'
[project]
name = "crystal-backend"
version = "0.1.0"
description = "Crystal FastAPI backend"
requires-python = ">=3.11"
dependencies = [
  "fastapi>=0.115.0",
  "uvicorn[standard]>=0.30.0",
  "pydantic>=2.8.0",
  "python-multipart>=0.0.9",
  "faster-whisper>=1.0.3",
]

[project.optional-dependencies]
test = [
  "pytest>=8.0.0",
  "httpx>=0.27.0",
]
EOF

cat > backend/Dockerfile <<'EOF'
FROM python:3.11-slim

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg espeak-ng \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir fastapi "uvicorn[standard]" pydantic python-multipart faster-whisper

# Piper is optional: if it cannot be installed, Crystal falls back to espeak-ng.
RUN pip install --no-cache-dir piper-tts==1.2.0 || echo "piper-tts unavailable, using espeak-ng fallback"

COPY app ./app
COPY pyproject.toml ./pyproject.toml

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat > backend/.dockerignore <<'EOF'
__pycache__
**/*.pyc
.pytest_cache
data
tests

EOF

cat > backend/app/__init__.py <<'EOF'

EOF

cat > backend/app/main.py <<'EOF'
from fastapi import FastAPI

from app.api.health import router as health_router
from app.api.chat import router as chat_router
from app.api.memory import router as memory_router
from app.api.voice import router as voice_router
from app.api.profile import router as profile_router
from app.core.database import init_db

app = FastAPI(title="Crystal API", version="0.1.0")


@app.on_event("startup")
def startup() -> None:
    init_db()


app.include_router(health_router, prefix="/health", tags=["health"])
app.include_router(chat_router, prefix="/chat", tags=["chat"])
app.include_router(memory_router, prefix="/memory", tags=["memory"])
app.include_router(voice_router, prefix="/voice", tags=["voice"])
app.include_router(profile_router, prefix="/profile", tags=["profile"])


@app.get("/")
def root():
    return {"name": "Crystal API", "status": "running"}
EOF

cat > backend/app/core/__init__.py <<'EOF'

EOF

cat > backend/app/core/config.py <<'EOF'
from pydantic import BaseModel
import os


class Settings(BaseModel):
    env: str = os.getenv("CRYSTAL_ENV", "development")
    mode: str = os.getenv("CRYSTAL_MODE", "hybrid")
    api_host: str = os.getenv("CRYSTAL_API_HOST", "0.0.0.0")
    api_port: int = int(os.getenv("CRYSTAL_API_PORT", "8000"))
    db_path: str = os.getenv("CRYSTAL_DB_PATH", "./data/crystal.db")
    vector_path: str = os.getenv("CRYSTAL_VECTOR_PATH", "./data/vector")


settings = Settings()
EOF

cat > backend/app/core/database.py <<'EOF'
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
EOF

cat > backend/app/chat/__init__.py <<'EOF'

EOF

cat > backend/app/migrations/001_init.sql <<'EOF'
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  mode TEXT NOT NULL,
  summary TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  format TEXT NOT NULL,
  token_count INTEGER DEFAULT 0,
  metadata_json TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY(session_id) REFERENCES sessions(id)
);

CREATE TABLE IF NOT EXISTS memory_items (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  content TEXT NOT NULL,
  embedding_id TEXT,
  confidence REAL DEFAULT 1.0,
  source_message_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS public_profiles (
  id TEXT PRIMARY KEY,
  query TEXT NOT NULL,
  display_name TEXT,
  canonical_url TEXT,
  source_count INTEGER DEFAULT 0,
  risk_level TEXT,
  last_analyzed_at TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS profile_scores (
  id TEXT PRIMARY KEY,
  profile_id TEXT NOT NULL,
  authenticity INTEGER NOT NULL,
  activity INTEGER NOT NULL,
  influence INTEGER NOT NULL,
  relevance INTEGER NOT NULL,
  risk INTEGER NOT NULL,
  source_quality REAL NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(profile_id) REFERENCES public_profiles(id)
);

CREATE TABLE IF NOT EXISTS evidence_items (
  id TEXT PRIMARY KEY,
  profile_id TEXT NOT NULL,
  source_type TEXT NOT NULL,
  url TEXT NOT NULL,
  title TEXT,
  claim TEXT NOT NULL,
  confidence REAL NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(profile_id) REFERENCES public_profiles(id)
);

CREATE TABLE IF NOT EXISTS artifacts (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  type TEXT NOT NULL,
  title TEXT,
  mime_type TEXT NOT NULL,
  storage_url TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY(session_id) REFERENCES sessions(id)
);
EOF

cat > backend/app/api/__init__.py <<'EOF'

EOF

cat > backend/app/api/health.py <<'EOF'
from fastapi import APIRouter

router = APIRouter()


@router.get("")
def health():
    return {"status": "ok", "mode": "hybrid", "version": "0.1.0"}
EOF

cat > backend/app/schemas/__init__.py <<'EOF'

EOF

cat > backend/app/schemas/chat.py <<'EOF'
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
EOF

cat > backend/app/memory/__init__.py <<'EOF'

EOF

cat > backend/app/memory/models.py <<'EOF'
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
EOF

cat > backend/app/memory/repository.py <<'EOF'
from __future__ import annotations

from app.core.database import get_connection
from app.memory.models import MemoryItem


class MemoryRepository:
    def save(self, item: MemoryItem) -> MemoryItem:
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO memory_items (
                    id, user_id, kind, content, embedding_id, confidence,
                    source_message_id, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    item.id,
                    item.user_id,
                    item.kind,
                    item.content,
                    None,
                    item.confidence,
                    item.source_message_id,
                    item.created_at,
                    item.updated_at,
                ),
            )
            conn.commit()
        return item

    def search(self, user_id: str, query: str, limit: int = 5) -> list[dict]:
        with get_connection() as conn:
            cursor = conn.execute(
                """
                SELECT id, user_id, kind, content, confidence, source_message_id, created_at, updated_at
                FROM memory_items
                WHERE user_id = ? AND content LIKE ?
                ORDER BY created_at DESC
                LIMIT ?
                """,
                (user_id, f"%{query}%", limit),
            )
            rows = cursor.fetchall()
        return [dict(row) for row in rows]

    def recent(self, user_id: str, limit: int = 3) -> list[dict]:
        with get_connection() as conn:
            cursor = conn.execute(
                """
                SELECT id, user_id, kind, content, confidence, source_message_id, created_at, updated_at
                FROM memory_items
                WHERE user_id = ?
                ORDER BY created_at DESC
                LIMIT ?
                """,
                (user_id, limit),
            )
            rows = cursor.fetchall()
        return [dict(row) for row in rows]
EOF

cat > backend/app/chat/repository.py <<'EOF'
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
EOF

cat > backend/app/orchestration/__init__.py <<'EOF'

EOF

cat > backend/app/orchestration/orchestrator.py <<'EOF'
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
EOF

cat > backend/app/api/chat.py <<'EOF'
from fastapi import APIRouter
from app.orchestration.orchestrator import Orchestrator
from app.schemas.chat import ChatRequest, ChatResponse

router = APIRouter()
orchestrator = Orchestrator()


@router.post("/message", response_model=ChatResponse)
def message(payload: ChatRequest):
    return orchestrator.respond(payload)
EOF

cat > backend/app/api/memory.py <<'EOF'
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
EOF

cat > backend/app/schemas/profile.py <<'EOF'
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
EOF

cat > backend/app/analysis/__init__.py <<'EOF'

EOF

cat > backend/app/analysis/scoring.py <<'EOF'
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
EOF

cat > backend/app/analysis/public_profile.py <<'EOF'
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
EOF

cat > backend/app/api/profile.py <<'EOF'
from fastapi import APIRouter
from app.analysis.public_profile import build_public_profile_report
from app.schemas.profile import ProfileAnalyzeRequest, ProfileAnalyzeResponse

router = APIRouter()


@router.post("/analyze", response_model=ProfileAnalyzeResponse)
def analyze(payload: ProfileAnalyzeRequest):
    return build_public_profile_report(
        query=payload.query,
        signals=payload.signals,
        evidence=payload.evidence,
        scoring_profile=payload.scoring_profile,
    )
EOF

cat > backend/app/voice/__init__.py <<'EOF'

EOF

cat > backend/app/voice/stt.py <<'EOF'
from __future__ import annotations

import os
import tempfile
from typing import Any


class WhisperTranscriber:
    def __init__(self, model_name: str | None = None):
        self.model_name = model_name or os.getenv("CRYSTAL_WHISPER_MODEL", "base")
        self._model = None

    @property
    def model(self):
        if self._model is None:
            try:
                from faster_whisper import WhisperModel
            except Exception as exc:  # pragma: no cover - import guard
                raise RuntimeError(
                    "faster-whisper is not installed. Install backend dependencies to enable voice transcription."
                ) from exc
            self._model = WhisperModel(self.model_name, device="cpu", compute_type="int8")
        return self._model

    def transcribe_bytes(self, audio_bytes: bytes, language: str | None = None) -> dict[str, Any]:
        with tempfile.NamedTemporaryFile(suffix=".webm", delete=True) as audio_file:
            audio_file.write(audio_bytes)
            audio_file.flush()
            segments, info = self.model.transcribe(audio_file.name, language=language)
            text = " ".join(segment.text.strip() for segment in segments).strip()
            return {
                "text": text,
                "language": getattr(info, "language", language or "unknown"),
                "confidence": float(getattr(info, "probability", 0.0)),
            }
EOF

cat > backend/app/voice/tts.py <<'EOF'
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path


class PiperSpeaker:
    def __init__(self, model_path: str | None = None, config_path: str | None = None):
        self.model_path = model_path or os.getenv("CRYSTAL_PIPER_MODEL", "")
        self.config_path = config_path or os.getenv("CRYSTAL_PIPER_CONFIG", "")

    def _speak_with_piper(self, text: str) -> bytes:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            output_path = tmpdir_path / "output.wav"

            command = [
                "piper",
                "--model",
                self.model_path,
                "--output_file",
                str(output_path),
            ]
            if self.config_path:
                command.extend(["--config", self.config_path])

            subprocess.run(
                command,
                input=text.encode("utf-8"),
                check=True,
            )
            return output_path.read_bytes()

    def _speak_with_espeak(self, text: str) -> bytes:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            output_path = tmpdir_path / "output.wav"
            subprocess.run(
                ["espeak-ng", "-w", str(output_path), text],
                check=True,
            )
            return output_path.read_bytes()

    def synthesize_to_wav(self, text: str) -> bytes:
        if self.model_path and shutil.which("piper"):
            return self._speak_with_piper(text)
        if shutil.which("espeak-ng"):
            return self._speak_with_espeak(text)
        raise RuntimeError(
            "No voice engine is available. Install piper or ensure espeak-ng is present in the container."
        )
EOF

cat > backend/app/api/voice.py <<'EOF'
from __future__ import annotations

from fastapi import APIRouter, File, UploadFile
from fastapi.responses import Response
from pydantic import BaseModel

from app.voice.stt import WhisperTranscriber
from app.voice.tts import PiperSpeaker

router = APIRouter()
transcriber = WhisperTranscriber()
speaker = PiperSpeaker()


class SynthesizeRequest(BaseModel):
    text: str
    voice: str = "default"
    style: str = "warm"


@router.post("/transcribe")
async def transcribe(audio: UploadFile = File(...)):
    data = await audio.read()
    result = transcriber.transcribe_bytes(data)
    return result


@router.post("/synthesize")
def synthesize(payload: SynthesizeRequest):
    wav_bytes = speaker.synthesize_to_wav(payload.text)
    return Response(content=wav_bytes, media_type="audio/wav")
EOF

cat > backend/tests/__init__.py <<'EOF'

EOF

cat > backend/tests/test_api.py <<'EOF'
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
EOF

cat > apps/desktop/package.json <<'EOF'
{
  "name": "crystal-desktop",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "typecheck": "tsc --noEmit",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@types/react": "^18.3.3",
    "@types/react-dom": "^18.3.0",
    "@vitejs/plugin-react": "^4.3.1",
    "typescript": "^5.5.4",
    "vite": "^5.4.2"
  }
}
EOF

cat > apps/desktop/tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true
  },
  "include": ["src"]
}
EOF

cat > apps/desktop/vite.config.ts <<'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    allowedHosts: ['crystal.localhost', 'localhost', 'frontend'],
  },
})
EOF

cat > apps/desktop/index.html <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Crystal</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

cat > apps/desktop/Dockerfile <<'EOF'
FROM node:20-alpine

WORKDIR /app
ENV NODE_ENV=development

COPY package.json ./package.json
RUN npm install

COPY index.html ./index.html
COPY src ./src
COPY vite.config.ts ./vite.config.ts
COPY tsconfig.json ./tsconfig.json

EXPOSE 5173

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
EOF

cat > apps/desktop/Dockerfile.prod <<'EOF'
FROM node:20-alpine AS build

WORKDIR /app
COPY package.json ./package.json
RUN npm install
COPY index.html ./index.html
COPY src ./src
COPY vite.config.ts ./vite.config.ts
COPY tsconfig.json ./tsconfig.json
RUN npm run build

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

cat > apps/desktop/.dockerignore <<'EOF'
node_modules
dist

EOF

cat > apps/desktop/nginx.conf <<'EOF'
server {
  listen 80;
  server_name _;

  root /usr/share/nginx/html;
  index index.html;

  location / {
    try_files $uri $uri/ /index.html;
  }

  location /api/ {
    proxy_pass http://backend:8000/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
EOF

cat > apps/desktop/src/main.tsx <<'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

cat > apps/desktop/src/vite-env.d.ts <<'EOF'
/// <reference types="vite/client" />
EOF

cat > apps/desktop/src/App.tsx <<'EOF'
import { useState } from 'react'
import { postChatMessage } from './services/apiClient'
import VoicePanel from './components/VoicePanel'

export default function App() {
  const [message, setMessage] = useState('Hello Crystal')
  const [response, setResponse] = useState('')
  const [busy, setBusy] = useState(false)

  async function send() {
    setBusy(true)
    try {
      const data = await postChatMessage({
        session_id: 'sess_001',
        user_id: 'user_001',
        message,
        mode: 'auto',
        response_format: 'text',
      })
      setResponse(data.assistant_text ?? 'No response')
    } catch (error) {
      setResponse(`Error: ${(error as Error).message}`)
    } finally {
      setBusy(false)
    }
  }

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui', maxWidth: 720 }}>
      <h1>Crystal</h1>
      <p>Hybrid AI companion starter.</p>
      <textarea
        value={message}
        onChange={(e) => setMessage(e.target.value)}
        rows={4}
        style={{ width: '100%', padding: 12, marginBottom: 12, boxSizing: 'border-box' }}
      />
      <button onClick={send} disabled={busy} style={{ padding: '10px 16px' }}>
        {busy ? 'Sending...' : 'Send'}
      </button>
      <section style={{ marginTop: 20 }}>
        <h2>Reply</h2>
        <pre style={{ whiteSpace: 'pre-wrap' }}>{response}</pre>
      </section>
      <VoicePanel />
    </main>
  )
}
EOF

cat > apps/desktop/src/components/VoicePanel.tsx <<'EOF'
import { useRef, useState } from 'react'
import { postChatMessage } from '../services/apiClient'
import { synthesizeVoice, transcribeVoice } from '../services/voiceClient'

export default function VoicePanel() {
  const [recording, setRecording] = useState(false)
  const [status, setStatus] = useState('Idle')
  const [reply, setReply] = useState('')
  const mediaRef = useRef<MediaRecorder | null>(null)
  const chunksRef = useRef<BlobPart[]>([])

  async function startRecording() {
    let stream: MediaStream
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch (error) {
      setStatus(`Microphone unavailable: ${(error as Error).message}`)
      return
    }
    const recorder = new MediaRecorder(stream)
    chunksRef.current = []
    recorder.ondataavailable = (event) => {
      if (event.data.size > 0) chunksRef.current.push(event.data)
    }
    recorder.onstop = async () => {
      stream.getTracks().forEach((track) => track.stop())
      try {
        setStatus('Transcribing...')
        const audioBlob = new Blob(chunksRef.current, { type: recorder.mimeType || 'audio/webm' })
        const transcript = await transcribeVoice(audioBlob)
        if (!transcript.text) {
          setStatus('No speech detected')
          return
        }
        setStatus('Thinking...')
        const chat = await postChatMessage({
          session_id: 'sess_voice',
          user_id: 'voice_user',
          message: transcript.text,
          mode: 'auto',
          response_format: 'text',
        })
        setReply(chat.assistant_text)
        setStatus('Speaking...')
        const ttsBlob = await synthesizeVoice(chat.assistant_text)
        const audioUrl = URL.createObjectURL(ttsBlob)
        const audio = new Audio(audioUrl)
        await audio.play()
        setStatus('Done')
      } catch (error) {
        setStatus(`Voice flow failed: ${(error as Error).message}`)
      }
    }
    recorder.start()
    mediaRef.current = recorder
    setRecording(true)
    setStatus('Recording...')
  }

  function stopRecording() {
    mediaRef.current?.stop()
    mediaRef.current = null
    setRecording(false)
  }

  return (
    <section style={{ border: '1px solid #ccc', padding: 16, borderRadius: 12, marginTop: 16 }}>
      <h2>Voice</h2>
      <p>Status: {status}</p>
      <button onClick={recording ? stopRecording : startRecording}>
        {recording ? 'Stop voice capture' : 'Start voice capture'}
      </button>
      <pre style={{ whiteSpace: 'pre-wrap', marginTop: 16 }}>{reply}</pre>
    </section>
  )
}
EOF

cat > apps/desktop/src/services/apiClient.ts <<'EOF'
const API_URL = import.meta.env.VITE_API_URL || '/api'

export async function postChatMessage(payload: unknown) {
  const res = await fetch(`${API_URL}/chat/message`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
  if (!res.ok) {
    throw new Error(`Chat request failed: ${res.status}`)
  }
  return res.json()
}
EOF

cat > apps/desktop/src/services/voiceClient.ts <<'EOF'
const API_URL = import.meta.env.VITE_API_URL || '/api'

export async function transcribeVoice(audioBlob: Blob) {
  const form = new FormData()
  form.append('audio', audioBlob, 'voice.webm')

  const res = await fetch(`${API_URL}/voice/transcribe`, {
    method: 'POST',
    body: form,
  })
  if (!res.ok) {
    throw new Error(`Transcription failed: ${res.status}`)
  }
  return res.json()
}

export async function synthesizeVoice(text: string): Promise<Blob> {
  const res = await fetch(`${API_URL}/voice/synthesize`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text }),
  })
  if (!res.ok) {
    throw new Error(`Synthesis failed: ${res.status}`)
  }
  return res.blob()
}
EOF

cat > apps/desktop/src/types/profile.ts <<'EOF'
export type ProfileScores = {
  authenticity: number
  activity: number
  influence: number
  relevance: number
  risk: number
}
EOF

cat > shared/contracts/message.ts <<'EOF'
export type ChatRequest = {
  session_id: string
  user_id?: string
  message: string
  mode?: 'auto' | 'offline' | 'online'
  response_format?: 'text' | 'rich' | 'voice' | 'chart'
}

export type ChatResponse = {
  message_id: string
  assistant_text: string
  mode_used: string
  artifacts: Array<{ type: string; id: string; title?: string }>
  citations: unknown[]
  memory_updates: unknown[]
  warnings: string[]
}
EOF

cat > shared/contracts/profile.ts <<'EOF'
export type ProfileScores = {
  authenticity: number
  activity: number
  influence: number
  relevance: number
  risk: number
  source_quality: number
}
EOF

cat > docs/api.md <<'EOF'
# Crystal API

## Health
- `GET /health`

## Chat
- `POST /chat/message`

## Memory
- `POST /memory/remember`
- `GET /memory/search`

## Voice
- `POST /voice/transcribe`
- `POST /voice/synthesize`

## Profile Analysis
- `POST /profile/analyze`
EOF

cat > docs/data-model.md <<'EOF'
# Crystal Data Model

## Core objects
- Session
- Message
- MemoryItem
- PublicProfile
- ProfileScore
- EvidenceItem
- Artifact

## Storage
- SQLite for relational data
- vector store for semantic retrieval
EOF

echo "Crystal repo scaffold created in: $ROOT"
