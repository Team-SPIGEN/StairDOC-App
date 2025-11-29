from functools import lru_cache
from typing import Any, List

from pydantic import AnyHttpUrl, Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "StairDOC API"
    api_v1_prefix: str = "/api/v1"
    secret_key: str = Field(..., alias="SECRET_KEY")
    access_token_expire_minutes: int = Field(30, alias="ACCESS_TOKEN_EXPIRE_MINUTES")
    refresh_token_expire_minutes: int = Field(60 * 24 * 30, alias="REFRESH_TOKEN_EXPIRE_MINUTES")
    database_url: str = Field("sqlite+aiosqlite:///./stairdoc.db", alias="DATABASE_URL")
    allowed_origins: List[AnyHttpUrl | str] = Field(default_factory=list, alias="ALLOWED_ORIGINS")

    @field_validator("allowed_origins", mode="before")
    @classmethod
    def split_origins(cls, value: Any) -> List[str] | Any:
        if isinstance(value, str):
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[arg-type]
