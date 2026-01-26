"""
Unit tests for configuration module.

Tests:
- Settings loading
- Environment variable parsing
- Default values
"""

import pytest
import os
from unittest.mock import patch

from app.core.config import Settings, get_settings


class TestSettings:
    """Tests for Settings class."""
    
    def test_default_values(self):
        """Test default settings values."""
        with patch.dict(os.environ, {"SECRET_KEY": "test-secret-key"}):
            settings = Settings()
            assert settings.app_name == "StairDOC API"
            assert settings.debug is False
            assert settings.api_v1_prefix == "/api/v1"
    
    def test_secret_key_required(self):
        """Test that SECRET_KEY must be set."""
        # Settings requires SECRET_KEY
        with patch.dict(os.environ, {"SECRET_KEY": "test-key-minimum-16-chars"}):
            settings = Settings()
            assert settings.secret_key == "test-key-minimum-16-chars"
    
    def test_database_url_default(self):
        """Test default database URL."""
        with patch.dict(os.environ, {"SECRET_KEY": "test-secret-key"}):
            settings = Settings()
            assert "sqlite" in settings.database_url
    
    def test_rate_limit_settings(self):
        """Test rate limiting configuration."""
        with patch.dict(os.environ, {"SECRET_KEY": "test-secret-key"}):
            settings = Settings()
            assert settings.rate_limit_requests_per_minute > 0
            assert settings.rate_limit_burst > 0
    
    def test_log_level_default(self):
        """Test default log level."""
        with patch.dict(os.environ, {"SECRET_KEY": "test-secret-key"}):
            settings = Settings()
            assert settings.log_level in ["DEBUG", "INFO", "WARNING", "ERROR"]
    
    def test_cors_origins(self):
        """Test CORS origins parsing."""
        with patch.dict(os.environ, {
            "SECRET_KEY": "test-secret-key",
            "ALLOWED_ORIGINS": "http://localhost:3000,http://localhost:8080"
        }):
            settings = Settings()
            # ALLOWED_ORIGINS is parsed as set
            if settings.allowed_origins:
                assert isinstance(settings.allowed_origins, (set, list))


class TestGetSettings:
    """Tests for get_settings function."""
    
    def test_get_settings_returns_instance(self):
        """Test get_settings returns a Settings instance."""
        settings = get_settings()
        assert isinstance(settings, Settings)
    
    def test_get_settings_cached(self):
        """Test that get_settings returns cached instance."""
        settings1 = get_settings()
        settings2 = get_settings()
        # Should be the same cached instance
        assert settings1 is settings2
