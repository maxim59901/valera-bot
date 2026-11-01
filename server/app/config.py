from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_token: str = "change-me-to-a-long-secret"
    ollama_host: str = "http://127.0.0.1:11434"
    searxng_url: str = "http://127.0.0.1:8080"
    comfy_url: str = "http://127.0.0.1:8188"
    default_model: str = "llama3.1"
    vision_model: str = "llava"
    database_path: str = "./data/valera.db"
    media_dir: str = "./data/media"
    enable_search: bool = True
    enable_image_gen: bool = True
    host: str = "0.0.0.0"
    port: int = 8000
    cors_origins: str = "*"
    system_prompt: str = (
        "You are Valera Bot — a helpful, maximally truthful, and witty personal AI. "
        "Be direct, curious, and occasionally sarcastic — never cruel. Prefer clear answers "
        "over fluff. Speak naturally in the user's language."
    )

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def db_path(self) -> Path:
        return Path(self.database_path).resolve()

    @property
    def media_path(self) -> Path:
        return Path(self.media_dir).resolve()


@lru_cache
def get_settings() -> Settings:
    return Settings()
