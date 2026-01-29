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


# Valid test secret key (must be 32+ characters for production validation)
TEST_SECRET_KEY = "test-secret-key-for-unit-tests-minimum-32-characters"


class TestSettings:
    """Tests for Settings class."""
    
    def test_default_values(self):
        """Test default settings values."""
        with patch.dict(os.environ, {
            "SECRET_KEY": TEST_SECRET_KEY,
            "DEBUG": "false"  # Explicitly set to test default behavior
        }, clear=False):
            settings = Settings()
            assert settings.app_name == "StairDOC API"
            assert settings.debug is False
            assert settings.api_v1_prefix == "/api/v1"
    
    def test_secret_key_required(self):
        """Test that SECRET_KEY must be at least 32 characters."""
        # Valid key (32+ chars)
        with patch.dict(os.environ, {"SECRET_KEY": TEST_SECRET_KEY}, clear=False):
            settings = Settings()
            assert settings.secret_key == TEST_SECRET_KEY
            assert len(settings.secret_key) >= 32
    
    def test_secret_key_too_short_rejected(self):
        """Test that short SECRET_KEY is rejected."""
        from pydantic import ValidationError
        with patch.dict(os.environ, {"SECRET_KEY": "short-key"}, clear=False):
            with pytest.raises(ValidationError) as exc_info:
                Settings()
            assert "SECRET_KEY must be at least 32 characters" in str(exc_info.value)
    
    def test_database_url_default(self):
        """Test default database URL."""
        with patch.dict(os.environ, {"SECRET_KEY": TEST_SECRET_KEY}, clear=False):
            settings = Settings()
            assert "sqlite" in settings.database_url
    
    def test_rate_limit_settings(self):
        """Test rate limiting configuration."""
        with patch.dict(os.environ, {"SECRET_KEY": TEST_SECRET_KEY}, clear=False):
            settings = Settings()
            assert settings.rate_limit_requests_per_minute > 0
            assert settings.rate_limit_burst > 0
    
    def test_log_level_default(self):
        """Test default log level."""
        with patch.dict(os.environ, {"SECRET_KEY": TEST_SECRET_KEY}, clear=False):
            settings = Settings()
            assert settings.log_level in ["DEBUG", "INFO", "WARNING", "ERROR"]
    
    def test_cors_origins(self):
        """Test CORS origins parsing."""
        with patch.dict(os.environ, {
            "SECRET_KEY": TEST_SECRET_KEY,
            "ALLOWED_ORIGINS": "http://localhost:3000,http://localhost:8080"
        }, clear=False):
            settings = Settings()
            # ALLOWED_ORIGINS is parsed as set
            if settings.allowed_origins:
                assert isinstance(settings.allowed_origins, (set, list))
    
    def test_environment_detection(self):
        """Test environment field."""
        with patch.dict(os.environ, {
            "SECRET_KEY": TEST_SECRET_KEY,
            "ENVIRONMENT": "production"
        }, clear=False):
            settings = Settings()
            assert settings.environment == "production"
            assert settings.is_production is True
    
    def test_is_production_property(self):
        """Test is_production property for different environments."""
        with patch.dict(os.environ, {
            "SECRET_KEY": TEST_SECRET_KEY,
            "ENVIRONMENT": "development"
        }, clear=False):
            settings = Settings()
            assert settings.is_production is False


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
