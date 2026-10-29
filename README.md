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
- the repo cloned once into the deploy path
- optional Piper model files placed in `./voice-models/`

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
