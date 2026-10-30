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
