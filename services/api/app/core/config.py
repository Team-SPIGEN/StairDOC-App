from functools import lru_cache
from typing import Any, List, Optional, Set
import warnings

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Application settings
    app_name: str = "StairDOC API"
    app_version: str = "1.0.0"
    environment: str = Field(default="development", alias="ENVIRONMENT")
    debug: bool = Field(default=False, alias="DEBUG")
    api_v1_prefix: str = "/api/v1"
    
    # Security settings
    secret_key: str = Field(..., alias="SECRET_KEY")
    access_token_expire_minutes: int = Field(30, alias="ACCESS_TOKEN_EXPIRE_MINUTES")
    refresh_token_expire_minutes: int = Field(60 * 24 * 7, alias="REFRESH_TOKEN_EXPIRE_MINUTES")
    
    # Database settings
    database_url: str = Field("sqlite+aiosqlite:///./stairdoc.db", alias="DATABASE_URL")
    db_pool_size: int = Field(default=20, alias="DB_POOL_SIZE")
    db_max_overflow: int = Field(default=30, alias="DB_MAX_OVERFLOW")
    db_pool_timeout: int = Field(default=30, alias="DB_POOL_TIMEOUT")
    
    # Redis configuration for caching
    redis_url: Optional[str] = Field(default=None, alias="REDIS_URL")
    
    # CORS settings
    allowed_origins_str: str = Field(default="", alias="ALLOWED_ORIGINS")
    
    # Rate limiting settings
    rate_limit_enabled: bool = Field(default=True, alias="RATE_LIMIT_ENABLED")
    rate_limit_requests_per_minute: int = Field(default=100, alias="RATE_LIMIT_REQUESTS_PER_MINUTE")
    rate_limit_burst: int = Field(default=20, alias="RATE_LIMIT_BURST")
    
    # Logging settings
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    log_format: str = Field(default="json", alias="LOG_FORMAT")  # json or text
    log_requests: bool = Field(default=True, alias="LOG_REQUESTS")
    log_request_body: bool = Field(default=False, alias="LOG_REQUEST_BODY")
    log_response_body: bool = Field(default=False, alias="LOG_RESPONSE_BODY")
    
    # API Key authentication (for service-to-service)
    api_keys_str: str = Field(default="", alias="API_KEYS")
    
    # Request size limits (in bytes)
    max_request_size: int = Field(default=1_048_576, alias="MAX_REQUEST_SIZE")  # 1MB
    max_upload_size: int = Field(default=10_485_760, alias="MAX_UPLOAD_SIZE")  # 10MB
    
    # Sentry (error tracking)
    sentry_dsn: Optional[str] = Field(default=None, alias="SENTRY_DSN")

    @property
    def is_production(self) -> bool:
        """Check if running in production mode."""
        return self.environment.lower() == "production" or not self.debug

    @property
    def allowed_origins(self) -> Set[str]:
        """Parse ALLOWED_ORIGINS as comma-separated string."""
        if not self.allowed_origins_str:
            return set()
        return {origin.strip() for origin in self.allowed_origins_str.split(",") if origin.strip()}
    
    @property
    def api_keys(self) -> Set[str]:
        """Parse API_KEYS as comma-separated string."""
        if not self.api_keys_str:
            return set()
        return {key.strip() for key in self.api_keys_str.split(",") if key.strip()}
    
    @field_validator("log_level")
    @classmethod
    def validate_log_level(cls, v: str) -> str:
        """Validate log level."""
        valid_levels = {"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"}
        if v.upper() not in valid_levels:
            raise ValueError(f"Invalid log level. Must be one of: {valid_levels}")
        return v.upper()
    
    @field_validator("secret_key")
    @classmethod
    def validate_secret_key(cls, v: str) -> str:
        """Validate secret key strength."""
        if len(v) < 32:
            raise ValueError("SECRET_KEY must be at least 32 characters long")
        if v.startswith("CHANGE_ME") or v == "your-secret-key-here":
            raise ValueError("SECRET_KEY must be changed from the default value")
        return v
    
    @model_validator(mode="after")
    def validate_production_settings(self) -> "Settings":
        """Validate settings for production environment."""
        if self.is_production:
            # Warn about insecure settings in production
            if self.debug:
                warnings.warn("DEBUG=true in production is a security risk!", UserWarning)
            
            if "sqlite" in self.database_url.lower():
                warnings.warn("SQLite is not recommended for production. Use PostgreSQL.", UserWarning)
            
            if not self.redis_url:
                warnings.warn("Redis is recommended for production caching and rate limiting.", UserWarning)
            
            if self.log_request_body or self.log_response_body:
                warnings.warn("Logging request/response bodies in production may expose sensitive data.", UserWarning)
            
            if self.access_token_expire_minutes > 60:
                warnings.warn("Access token expiry > 60 minutes increases security risk.", UserWarning)
        
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[arg-type]
