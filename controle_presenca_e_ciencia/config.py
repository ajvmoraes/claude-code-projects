from functools import lru_cache
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    TENANT_ID: str
    CLIENT_ID: str
    CLIENT_SECRET: str
    REDIRECT_URI: str = "http://localhost:8000/auth/callback"
    SECRET_KEY: str
    FROM_EMAIL: str
    FROM_NAME: str = "Sistema de ATAs"
    DATABASE_URL: str = "sqlite+aiosqlite:///./atas.db"

    class Config:
        env_file = ".env"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
