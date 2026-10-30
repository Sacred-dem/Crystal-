#!/usr/bin/env bash
# Run Crystal locally without Docker: API on :8000, UI on :5173.
set -euo pipefail
cd "$(dirname "$0")/.."

export CRYSTAL_DB_PATH="${CRYSTAL_DB_PATH:-$PWD/backend/data/crystal.db}"

if [ ! -d apps/desktop/node_modules ]; then
  (cd apps/desktop && npm install)
fi

(cd backend && python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000) &
API_PID=$!
trap 'kill $API_PID 2>/dev/null || true' EXIT

echo "API:  http://localhost:8000/health"
echo "UI:   http://localhost:5173"
cd apps/desktop && npm run dev

