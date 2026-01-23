from functools import lru_cache
from typing import Any, Set

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "StairDOC API"
    api_v1_prefix: str = "/api/v1"
    secret_key: str = Field(..., alias="SECRET_KEY")
    access_token_expire_minutes: int = Field(30, alias="ACCESS_TOKEN_EXPIRE_MINUTES")
    refresh_token_expire_minutes: int = Field(60 * 24 * 30, alias="REFRESH_TOKEN_EXPIRE_MINUTES")
    database_url: str = Field("sqlite+aiosqlite:///./stairdoc.db", alias="DATABASE_URL")
    allowed_origins_str: str = Field(default="", alias="ALLOWED_ORIGINS")

    @property
    def allowed_origins(self) -> Set[str]:
        """Parse ALLOWED_ORIGINS as comma-separated string."""
        if not self.allowed_origins_str:
            return set()
        return {origin.strip() for origin in self.allowed_origins_str.split(",") if origin.strip()}


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[arg-type]
