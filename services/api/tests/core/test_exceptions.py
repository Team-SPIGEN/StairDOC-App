"""
Unit tests for exception handling module.

Tests:
- Custom exception classes
- Error response formatting
- Exception handler functions
"""

from datetime import datetime
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException, status

from app.core.exceptions import (
    AppException,
    AuthenticationError,
    AuthorizationError,
    ConflictError,
    ErrorDetail,
    ErrorResponse,
    NotFoundError,
    RateLimitError,
    ServiceUnavailableError,
    ValidationError_,
    get_correlation_id,
    _status_code_to_error,
)


class TestErrorModels:
    """Tests for error response models."""
    
    def test_error_detail_creation(self):
        """Test ErrorDetail model creation."""
        detail = ErrorDetail(
            loc=["body", "email"],
            msg="Invalid email format",
            type="value_error",
        )
        assert detail.loc == ["body", "email"]
        assert detail.msg == "Invalid email format"
        assert detail.type == "value_error"
    
    def test_error_detail_minimal(self):
        """Test ErrorDetail with minimal fields."""
        detail = ErrorDetail(msg="Something went wrong")
        assert detail.loc is None
        assert detail.type is None
    
    def test_error_response_creation(self):
        """Test ErrorResponse model creation."""
        response = ErrorResponse(
            error="VALIDATION_ERROR",
            message="Request validation failed",
            timestamp=datetime.utcnow(),
            path="/api/v1/test",
        )
        assert response.error == "VALIDATION_ERROR"
        assert response.message == "Request validation failed"
        assert response.path == "/api/v1/test"
    
    def test_error_response_with_details(self):
        """Test ErrorResponse with error details."""
        details = [
            ErrorDetail(loc=["body", "email"], msg="Invalid email"),
            ErrorDetail(loc=["body", "password"], msg="Too short"),
        ]
        response = ErrorResponse(
            error="VALIDATION_ERROR",
            message="Multiple validation errors",
            details=details,
            timestamp=datetime.utcnow(),
            correlation_id="abc-123",
            path="/api/v1/auth/register",
        )
        assert len(response.details) == 2
        assert response.correlation_id == "abc-123"


class TestAppException:
    """Tests for base AppException."""
    
    def test_default_values(self):
        """Test default exception values."""
        exc = AppException(message="Something went wrong")
        assert exc.message == "Something went wrong"
        assert exc.error_code == "APP_ERROR"
        assert exc.status_code == status.HTTP_500_INTERNAL_SERVER_ERROR
        assert exc.details is None
    
    def test_custom_values(self):
        """Test custom exception values."""
        details = [ErrorDetail(msg="Field error")]
        exc = AppException(
            message="Custom error",
            error_code="CUSTOM_ERROR",
            status_code=400,
            details=details,
        )
        assert exc.error_code == "CUSTOM_ERROR"
        assert exc.status_code == 400
        assert len(exc.details) == 1
    
    def test_exception_string(self):
        """Test exception string representation."""
        exc = AppException(message="Test error")
        assert str(exc) == "Test error"


class TestNotFoundError:
    """Tests for NotFoundError exception."""
    
    def test_resource_not_found(self):
        """Test basic not found error."""
        exc = NotFoundError(resource="User")
        assert "User not found" in exc.message
        assert exc.error_code == "NOT_FOUND"
        assert exc.status_code == status.HTTP_404_NOT_FOUND
    
    def test_resource_with_id(self):
        """Test not found error with resource ID."""
        exc = NotFoundError(resource="Delivery", resource_id="del-123")
        assert "Delivery" in exc.message
        assert "del-123" in exc.message


class TestAuthenticationError:
    """Tests for AuthenticationError exception."""
    
    def test_default_message(self):
        """Test default authentication error."""
        exc = AuthenticationError()
        assert exc.message == "Authentication required"
        assert exc.error_code == "AUTHENTICATION_ERROR"
        assert exc.status_code == status.HTTP_401_UNAUTHORIZED
    
    def test_custom_message(self):
        """Test custom authentication error message."""
        exc = AuthenticationError(message="Invalid credentials")
        assert exc.message == "Invalid credentials"


class TestAuthorizationError:
    """Tests for AuthorizationError exception."""
    
    def test_default_message(self):
        """Test default authorization error."""
        exc = AuthorizationError()
        assert exc.message == "Permission denied"
        assert exc.error_code == "AUTHORIZATION_ERROR"
        assert exc.status_code == status.HTTP_403_FORBIDDEN
    
    def test_custom_message(self):
        """Test custom authorization error message."""
        exc = AuthorizationError(message="Admin access required")
        assert exc.message == "Admin access required"


class TestRateLimitError:
    """Tests for RateLimitError exception."""
    
    def test_default_retry_after(self):
        """Test default retry after value."""
        exc = RateLimitError()
        assert exc.status_code == status.HTTP_429_TOO_MANY_REQUESTS
        assert exc.error_code == "RATE_LIMIT_EXCEEDED"
        assert exc.retry_after == 60
        assert "60" in exc.message
    
    def test_custom_retry_after(self):
        """Test custom retry after value."""
        exc = RateLimitError(retry_after=120)
        assert exc.retry_after == 120
        assert "120" in exc.message


class TestServiceUnavailableError:
    """Tests for ServiceUnavailableError exception."""
    
    def test_with_service_name(self):
        """Test service unavailable with service name."""
        exc = ServiceUnavailableError(service="Robot API")
        assert "Robot API" in exc.message
        assert exc.error_code == "SERVICE_UNAVAILABLE"
        assert exc.status_code == status.HTTP_503_SERVICE_UNAVAILABLE
    
    def test_with_custom_message(self):
        """Test service unavailable with custom message."""
        exc = ServiceUnavailableError(service="Redis", message="Cache not responding")
        assert exc.message == "Cache not responding"


class TestConflictError:
    """Tests for ConflictError exception."""
    
    def test_conflict_error(self):
        """Test conflict error creation."""
        exc = ConflictError(message="Email already registered")
        assert exc.message == "Email already registered"
        assert exc.error_code == "CONFLICT"
        assert exc.status_code == status.HTTP_409_CONFLICT


class TestValidationError:
    """Tests for ValidationError_ exception."""
    
    def test_validation_error(self):
        """Test validation error creation."""
        details = [ErrorDetail(loc=["body", "email"], msg="Invalid format")]
        exc = ValidationError_(message="Validation failed", details=details)
        assert exc.error_code == "VALIDATION_ERROR"
        assert exc.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
        assert len(exc.details) == 1


class TestHelperFunctions:
    """Tests for helper functions."""
    
    def test_get_correlation_id_from_state(self):
        """Test getting correlation ID from request state."""
        request = MagicMock()
        request.state.correlation_id = "test-corr-id"
        
        result = get_correlation_id(request)
        assert result == "test-corr-id"
    
    def test_get_correlation_id_from_headers(self):
        """Test getting correlation ID from headers."""
        request = MagicMock()
        del request.state.correlation_id  # Remove state attribute
        request.headers.get.return_value = "header-corr-id"
        
        # This should fall back to headers
        request.state = MagicMock(spec=[])  # Empty spec means no correlation_id
        result = get_correlation_id(request)
        # When state doesn't have correlation_id, falls back to header
    
    def test_status_code_to_error_mapping(self):
        """Test status code to error string mapping."""
        assert _status_code_to_error(400) == "BAD_REQUEST"
        assert _status_code_to_error(401) == "UNAUTHORIZED"
        assert _status_code_to_error(403) == "FORBIDDEN"
        assert _status_code_to_error(404) == "NOT_FOUND"
        assert _status_code_to_error(422) == "VALIDATION_ERROR"
        assert _status_code_to_error(429) == "RATE_LIMIT_EXCEEDED"
        assert _status_code_to_error(500) == "INTERNAL_SERVER_ERROR"
        assert _status_code_to_error(503) == "SERVICE_UNAVAILABLE"
    
    def test_unknown_status_code(self):
        """Test unknown status code returns generic error."""
        assert _status_code_to_error(418) == "ERROR"  # I'm a teapot
