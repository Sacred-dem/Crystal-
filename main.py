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
