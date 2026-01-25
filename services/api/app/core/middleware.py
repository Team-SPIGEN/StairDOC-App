"""
Security middleware for API protection.

Implements:
- Security headers (CORS, CSP, X-Frame-Options, etc.)
- Request validation (content-type, size limits)
- Input sanitization
- API key authentication for service-to-service calls
"""

import logging
import re
from typing import Callable, Dict, List, Optional, Set

from fastapi import Depends, HTTPException, Request, Security, status
from fastapi.security import APIKeyHeader
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

from .config import get_settings

logger = logging.getLogger(__name__)


# =============================================================================
# Security Headers Middleware
# =============================================================================

class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """
    Add security headers to all responses.
    
    Headers added:
    - X-Content-Type-Options: nosniff
    - X-Frame-Options: DENY
    - X-XSS-Protection: 1; mode=block
    - Strict-Transport-Security: max-age=31536000
    - Content-Security-Policy: default-src 'self'
    - Referrer-Policy: strict-origin-when-cross-origin
    """
    
    def __init__(
        self,
        app,
        enable_hsts: bool = True,
        hsts_max_age: int = 31536000,
        frame_options: str = "DENY",
        content_security_policy: Optional[str] = None,
    ):
        super().__init__(app)
        self.enable_hsts = enable_hsts
        self.hsts_max_age = hsts_max_age
        self.frame_options = frame_options
        self.csp = content_security_policy or "default-src 'self'"
    
    async def dispatch(self, request: Request, call_next) -> Response:
        """Add security headers to response."""
        response = await call_next(request)
        
        # Prevent MIME type sniffing
        response.headers["X-Content-Type-Options"] = "nosniff"
        
        # Prevent clickjacking
        response.headers["X-Frame-Options"] = self.frame_options
        
        # XSS protection (legacy browsers)
        response.headers["X-XSS-Protection"] = "1; mode=block"
        
        # Strict Transport Security (HTTPS only)
        if self.enable_hsts:
            response.headers["Strict-Transport-Security"] = (
                f"max-age={self.hsts_max_age}; includeSubDomains"
            )
        
        # Content Security Policy
        response.headers["Content-Security-Policy"] = self.csp
        
        # Referrer Policy
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        
        # Permissions Policy (modern replacement for Feature-Policy)
        response.headers["Permissions-Policy"] = (
            "accelerometer=(), camera=(), geolocation=(), gyroscope=(), "
            "magnetometer=(), microphone=(), payment=(), usb=()"
        )
        
        return response


# =============================================================================
# Request Validation Middleware
# =============================================================================

# Maximum request body sizes by content type
MAX_BODY_SIZES: Dict[str, int] = {
    "application/json": 1 * 1024 * 1024,  # 1MB for JSON
    "multipart/form-data": 10 * 1024 * 1024,  # 10MB for file uploads
    "application/x-www-form-urlencoded": 64 * 1024,  # 64KB for forms
    "default": 1 * 1024 * 1024,  # 1MB default
}

# Allowed content types
ALLOWED_CONTENT_TYPES: Set[str] = {
    "application/json",
    "multipart/form-data",
    "application/x-www-form-urlencoded",
    "text/plain",
}


class RequestValidationMiddleware(BaseHTTPMiddleware):
    """
    Validate incoming requests for security.
    
    Checks:
    - Content-Type header validity
    - Request body size limits
    - Required headers presence
    """
    
    def __init__(
        self,
        app,
        max_body_sizes: Optional[Dict[str, int]] = None,
        allowed_content_types: Optional[Set[str]] = None,
        require_content_type_for_body: bool = True,
    ):
        super().__init__(app)
        self.max_body_sizes = max_body_sizes or MAX_BODY_SIZES
        self.allowed_content_types = allowed_content_types or ALLOWED_CONTENT_TYPES
        self.require_content_type_for_body = require_content_type_for_body
    
    async def dispatch(self, request: Request, call_next) -> Response:
        """Validate request before processing."""
        # Skip validation for GET, HEAD, OPTIONS
        if request.method in ("GET", "HEAD", "OPTIONS"):
            return await call_next(request)
        
        content_type = request.headers.get("content-type", "")
        content_length = request.headers.get("content-length")
        
        # Extract base content type (without charset, boundary, etc.)
        base_content_type = content_type.split(";")[0].strip().lower()
        
        # Validate content type for requests with body
        if content_length and int(content_length) > 0:
            if self.require_content_type_for_body and not content_type:
                return Response(
                    content='{"detail": "Content-Type header is required"}',
                    status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                    media_type="application/json",
                )
            
            if base_content_type and base_content_type not in self.allowed_content_types:
                return Response(
                    content='{"detail": "Unsupported Content-Type"}',
                    status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                    media_type="application/json",
                )
            
            # Check body size
            max_size = self.max_body_sizes.get(
                base_content_type,
                self.max_body_sizes.get("default", 1024 * 1024)
            )
            
            if content_length and int(content_length) > max_size:
                return Response(
                    content=f'{{"detail": "Request body too large. Maximum size: {max_size} bytes"}}',
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    media_type="application/json",
                )
        
        return await call_next(request)


# =============================================================================
# Input Sanitization
# =============================================================================

# Patterns that might indicate injection attempts
INJECTION_PATTERNS = [
    re.compile(r'<script[^>]*>', re.IGNORECASE),
    re.compile(r'javascript:', re.IGNORECASE),
    re.compile(r'on\w+\s*=', re.IGNORECASE),  # onclick, onerror, etc.
    re.compile(r'data:\s*text/html', re.IGNORECASE),
]

# SQL injection patterns (basic detection)
SQL_INJECTION_PATTERNS = [
    re.compile(r"'\s*or\s+'1'\s*=\s*'1", re.IGNORECASE),
    re.compile(r";\s*drop\s+table", re.IGNORECASE),
    re.compile(r";\s*delete\s+from", re.IGNORECASE),
    re.compile(r"union\s+select", re.IGNORECASE),
]


def sanitize_string(value: str, allow_html: bool = False) -> str:
    """
    Sanitize a string value to prevent XSS and injection attacks.
    
    Args:
        value: Input string to sanitize
        allow_html: If False, escape HTML entities
    
    Returns:
        Sanitized string
    """
    if not isinstance(value, str):
        return value
    
    # Check for injection patterns
    for pattern in INJECTION_PATTERNS:
        if pattern.search(value):
            logger.warning(f"Potential XSS attempt detected: {value[:100]}")
            # Remove the dangerous content
            value = pattern.sub("", value)
    
    # Check for SQL injection patterns
    for pattern in SQL_INJECTION_PATTERNS:
        if pattern.search(value):
            logger.warning(f"Potential SQL injection attempt: {value[:100]}")
            # Don't modify - let the ORM handle it, just log
    
    if not allow_html:
        # Escape HTML entities
        value = (
            value
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;")
            .replace("'", "&#x27;")
        )
    
    return value


def sanitize_dict(data: dict, allow_html_fields: Optional[Set[str]] = None) -> dict:
    """
    Recursively sanitize all string values in a dictionary.
    
    Args:
        data: Dictionary to sanitize
        allow_html_fields: Set of field names where HTML is allowed
    
    Returns:
        Sanitized dictionary
    """
    allow_html_fields = allow_html_fields or set()
    sanitized = {}
    
    for key, value in data.items():
        if isinstance(value, str):
            sanitized[key] = sanitize_string(value, allow_html=key in allow_html_fields)
        elif isinstance(value, dict):
            sanitized[key] = sanitize_dict(value, allow_html_fields)
        elif isinstance(value, list):
            sanitized[key] = [
                sanitize_dict(item, allow_html_fields) if isinstance(item, dict)
                else sanitize_string(item) if isinstance(item, str)
                else item
                for item in value
            ]
        else:
            sanitized[key] = value
    
    return sanitized


# =============================================================================
# API Key Authentication
# =============================================================================

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


class APIKeyValidator:
    """
    Validate API keys for service-to-service authentication.
    """
    
    def __init__(self):
        self._valid_keys: Set[str] = set()
        self._key_permissions: Dict[str, Set[str]] = {}
    
    def register_key(
        self,
        api_key: str,
        permissions: Optional[Set[str]] = None,
    ):
        """Register a valid API key with optional permissions."""
        self._valid_keys.add(api_key)
        if permissions:
            self._key_permissions[api_key] = permissions
    
    def validate(self, api_key: Optional[str]) -> bool:
        """Check if an API key is valid."""
        return api_key is not None and api_key in self._valid_keys
    
    def has_permission(self, api_key: str, permission: str) -> bool:
        """Check if an API key has a specific permission."""
        if api_key not in self._valid_keys:
            return False
        
        permissions = self._key_permissions.get(api_key)
        if permissions is None:
            return True  # No permissions defined = all access
        
        return permission in permissions or "*" in permissions


# Global API key validator
_api_key_validator = APIKeyValidator()


def get_api_key_validator() -> APIKeyValidator:
    """Get the global API key validator."""
    return _api_key_validator


async def verify_api_key(
    api_key: Optional[str] = Security(api_key_header),
) -> str:
    """
    Dependency for verifying API key.
    
    Usage:
        @router.get("/internal/endpoint")
        async def internal_endpoint(api_key: str = Depends(verify_api_key)):
            ...
    """
    validator = get_api_key_validator()
    
    if not validator.validate(api_key):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API key",
        )
    
    return api_key


def require_api_key_permission(permission: str):
    """
    Dependency factory for requiring specific API key permissions.
    
    Usage:
        @router.delete("/admin/resource")
        async def delete_resource(
            api_key: str = Depends(require_api_key_permission("admin:delete"))
        ):
            ...
    """
    async def dependency(
        api_key: Optional[str] = Security(api_key_header),
    ) -> str:
        validator = get_api_key_validator()
        
        if not validator.validate(api_key):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or missing API key",
            )
        
        if not validator.has_permission(api_key, permission):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"API key lacks required permission: {permission}",
            )
        
        return api_key
    
    return dependency
