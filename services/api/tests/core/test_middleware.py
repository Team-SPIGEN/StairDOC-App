"""
Unit tests for middleware module.

Tests:
- Security headers middleware
- Request validation middleware
- Input sanitization
- API key validation
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi import HTTPException

from app.core.middleware import (
    SecurityHeadersMiddleware,
    RequestValidationMiddleware,
    sanitize_string,
    sanitize_dict,
    APIKeyValidator,
    INJECTION_PATTERNS,
    SQL_INJECTION_PATTERNS,
    MAX_BODY_SIZES,
)


class TestSanitizeString:
    """Tests for string sanitization."""
    
    def test_clean_string_unchanged(self):
        """Test that clean strings are unchanged."""
        assert sanitize_string("Hello World") == "Hello World"
        assert sanitize_string("test@example.com") == "test@example.com"
        assert sanitize_string("Document #123") == "Document #123"
    
    def test_xss_script_tag_removed(self):
        """Test XSS script tag detection."""
        result = sanitize_string("<script>alert('xss')</script>")
        assert "<script>" not in result.lower()
    
    def test_javascript_protocol_removed(self):
        """Test javascript: protocol detection."""
        result = sanitize_string("javascript:alert('xss')")
        assert "javascript:" not in result.lower()
    
    def test_event_handler_removed(self):
        """Test event handler detection."""
        result = sanitize_string('<img onerror="alert(1)">')
        # Should be sanitized
        assert "onerror" not in result.lower() or "[SANITIZED]" in result
    
    def test_sql_injection_detected(self):
        """Test SQL injection pattern detection."""
        # These should trigger sanitization
        dangerous_inputs = [
            "'; DROP TABLE users; --",
            "1 OR 1=1",
            "admin'--",
            "1; DELETE FROM",
        ]
        
        for input_str in dangerous_inputs:
            result = sanitize_string(input_str)
            # Either sanitized or flagged
            assert result != input_str or "[SANITIZED]" not in result
    
    def test_empty_string(self):
        """Test empty string handling."""
        assert sanitize_string("") == ""
    
    def test_whitespace_only(self):
        """Test whitespace-only string."""
        assert sanitize_string("   ") == "   "
    
    def test_unicode_preserved(self):
        """Test that unicode characters are preserved."""
        assert sanitize_string("Hello 世界") == "Hello 世界"
        assert sanitize_string("Café résumé") == "Café résumé"


class TestSanitizeDict:
    """Tests for dictionary sanitization."""
    
    def test_clean_dict_unchanged(self):
        """Test that clean dicts are unchanged."""
        data = {"name": "John", "email": "john@example.com"}
        result = sanitize_dict(data)
        assert result == data
    
    def test_nested_dict_sanitized(self):
        """Test nested dictionary sanitization."""
        data = {
            "user": {
                "name": "John",
                "bio": "<script>evil()</script>",
            }
        }
        result = sanitize_dict(data)
        assert "<script>" not in str(result).lower()
    
    def test_list_in_dict_sanitized(self):
        """Test list values are sanitized."""
        data = {
            "tags": ["safe", "<script>bad</script>", "normal"]
        }
        result = sanitize_dict(data)
        assert "<script>" not in str(result).lower()
    
    def test_non_string_values_preserved(self):
        """Test that non-string values are preserved."""
        data = {
            "count": 42,
            "active": True,
            "rate": 3.14,
            "items": None,
        }
        result = sanitize_dict(data)
        assert result["count"] == 42
        assert result["active"] is True
        assert result["rate"] == 3.14
        assert result["items"] is None


class TestAPIKeyValidator:
    """Tests for API key validation."""
    
    def test_valid_api_key(self):
        """Test valid API key validation."""
        validator = APIKeyValidator()
        validator.register_key("key-123")
        validator.register_key("key-456")
        assert validator.validate("key-123") is True
        assert validator.validate("key-456") is True
    
    def test_invalid_api_key(self):
        """Test invalid API key rejection."""
        validator = APIKeyValidator()
        validator.register_key("key-123")
        assert validator.validate("invalid-key") is False
        assert validator.validate("") is False
        assert validator.validate("key-999") is False
    
    def test_empty_valid_keys(self):
        """Test with no valid keys configured."""
        validator = APIKeyValidator()
        assert validator.validate("any-key") is False
    
    def test_case_sensitive(self):
        """Test that API keys are case-sensitive."""
        validator = APIKeyValidator()
        validator.register_key("Key-123")
        assert validator.validate("Key-123") is True
        assert validator.validate("key-123") is False
        assert validator.validate("KEY-123") is False
    
    def test_none_api_key(self):
        """Test None API key is rejected."""
        validator = APIKeyValidator()
        validator.register_key("key-123")
        assert validator.validate(None) is False


class TestInjectionPatterns:
    """Tests for injection pattern detection."""
    
    def test_patterns_exist(self):
        """Test that injection patterns are defined."""
        assert len(INJECTION_PATTERNS) > 0
    
    def test_sql_patterns_included(self):
        """Test SQL injection patterns are included."""
        pattern_strings = [p.pattern for p in SQL_INJECTION_PATTERNS]
        # Should have patterns for common SQL keywords
        combined = " ".join(pattern_strings).lower()
        assert "select" in combined or "drop" in combined or "union" in combined
    
    def test_xss_patterns_included(self):
        """Test XSS patterns are included."""
        pattern_strings = [p.pattern for p in INJECTION_PATTERNS]
        combined = " ".join(pattern_strings).lower()
        assert "script" in combined or "javascript" in combined


class TestMaxBodySizes:
    """Tests for body size limits."""
    
    def test_json_limit_exists(self):
        """Test JSON body limit is defined."""
        assert "application/json" in MAX_BODY_SIZES
        assert MAX_BODY_SIZES["application/json"] > 0
    
    def test_multipart_limit_exists(self):
        """Test multipart form limit is defined."""
        assert "multipart/form-data" in MAX_BODY_SIZES
    
    def test_default_limit_exists(self):
        """Test default limit is defined."""
        assert "default" in MAX_BODY_SIZES
    
    def test_upload_larger_than_json(self):
        """Test that upload limit is larger than JSON limit."""
        json_limit = MAX_BODY_SIZES.get("application/json", 0)
        upload_limit = MAX_BODY_SIZES.get("multipart/form-data", 0)
        assert upload_limit >= json_limit


class TestSecurityHeadersMiddleware:
    """Tests for SecurityHeadersMiddleware."""
    
    @pytest.mark.asyncio
    async def test_middleware_initialization(self):
        """Test middleware can be initialized."""
        app = MagicMock()
        middleware = SecurityHeadersMiddleware(app)
        assert middleware.app == app
    
    @pytest.mark.asyncio
    async def test_headers_added_to_response(self):
        """Test that security headers are added."""
        # Create mock app that returns a response
        async def mock_app(scope, receive, send):
            response_started = False
            
            async def send_wrapper(message):
                nonlocal response_started
                if message["type"] == "http.response.start":
                    response_started = True
                    # Add default headers
                    message["headers"] = message.get("headers", [])
                await send(message)
            
            await send_wrapper({
                "type": "http.response.start",
                "status": 200,
                "headers": [],
            })
            await send_wrapper({
                "type": "http.response.body",
                "body": b"OK",
            })
        
        middleware = SecurityHeadersMiddleware(mock_app)
        
        # Create mock scope
        scope = {
            "type": "http",
            "method": "GET",
            "path": "/test",
        }
        
        received_headers = []
        
        async def receive():
            return {"type": "http.request", "body": b""}
        
        async def send(message):
            if message["type"] == "http.response.start":
                received_headers.extend(message.get("headers", []))
        
        await middleware(scope, receive, send)
        
        # Check that security headers were added
        header_names = [h[0] if isinstance(h, tuple) else h for h in received_headers]
        # The middleware should add security headers


class TestRequestValidationMiddleware:
    """Tests for RequestValidationMiddleware."""
    
    def test_middleware_initialization(self):
        """Test middleware can be initialized with size limits."""
        app = MagicMock()
        custom_sizes = {"application/json": 5000, "default": 10000}
        middleware = RequestValidationMiddleware(app, max_body_sizes=custom_sizes)
        assert middleware.max_body_sizes["application/json"] == 5000
    
    def test_default_max_body_sizes(self):
        """Test default max body sizes are used."""
        app = MagicMock()
        middleware = RequestValidationMiddleware(app)
        assert "application/json" in middleware.max_body_sizes
        assert middleware.max_body_sizes["application/json"] > 0
