"""
Custom exception handlers for consistent error responses.

Provides:
- Structured error responses with correlation IDs
- Detailed validation error messages
- Proper logging of exceptions
- Custom exception classes
"""

import logging
import traceback
from datetime import datetime
from typing import Any, Dict, List, Optional, Union

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger(__name__)


# =============================================================================
# Error Response Models
# =============================================================================

class ErrorDetail(BaseModel):
    """Detail about a specific error."""
    loc: Optional[List[str]] = None  # Location of error (e.g., ["body", "email"])
    msg: str
    type: Optional[str] = None


class ErrorResponse(BaseModel):
    """Standardized error response format."""
    error: str  # Error code/type
    message: str  # Human-readable message
    details: Optional[List[ErrorDetail]] = None
    timestamp: datetime
    correlation_id: Optional[str] = None
    path: str


# =============================================================================
# Custom Exceptions
# =============================================================================

class AppException(Exception):
    """Base exception for application errors."""
    
    def __init__(
        self,
        message: str,
        error_code: str = "APP_ERROR",
        status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR,
        details: Optional[List[ErrorDetail]] = None,
    ):
        self.message = message
        self.error_code = error_code
        self.status_code = status_code
        self.details = details
        super().__init__(message)


class NotFoundError(AppException):
    """Resource not found."""
    
    def __init__(
        self,
        resource: str,
        resource_id: Optional[str] = None,
    ):
        message = f"{resource} not found"
        if resource_id:
            message = f"{resource} with ID '{resource_id}' not found"
        super().__init__(
            message=message,
            error_code="NOT_FOUND",
            status_code=status.HTTP_404_NOT_FOUND,
        )


class ValidationError_(AppException):
    """Input validation error."""
    
    def __init__(
        self,
        message: str,
        details: Optional[List[ErrorDetail]] = None,
    ):
        super().__init__(
            message=message,
            error_code="VALIDATION_ERROR",
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            details=details,
        )


class AuthenticationError(AppException):
    """Authentication failed."""
    
    def __init__(self, message: str = "Authentication required"):
        super().__init__(
            message=message,
            error_code="AUTHENTICATION_ERROR",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )


class AuthorizationError(AppException):
    """Authorization failed."""
    
    def __init__(self, message: str = "Permission denied"):
        super().__init__(
            message=message,
            error_code="AUTHORIZATION_ERROR",
            status_code=status.HTTP_403_FORBIDDEN,
        )


class RateLimitError(AppException):
    """Rate limit exceeded."""
    
    def __init__(self, retry_after: int = 60):
        super().__init__(
            message=f"Rate limit exceeded. Retry after {retry_after} seconds.",
            error_code="RATE_LIMIT_EXCEEDED",
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        )
        self.retry_after = retry_after


class ServiceUnavailableError(AppException):
    """External service unavailable."""
    
    def __init__(self, service: str, message: Optional[str] = None):
        super().__init__(
            message=message or f"Service '{service}' is temporarily unavailable",
            error_code="SERVICE_UNAVAILABLE",
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        )


class ConflictError(AppException):
    """Resource conflict (e.g., duplicate)."""
    
    def __init__(self, message: str):
        super().__init__(
            message=message,
            error_code="CONFLICT",
            status_code=status.HTTP_409_CONFLICT,
        )


# =============================================================================
# Exception Handlers
# =============================================================================

def get_correlation_id(request: Request) -> Optional[str]:
    """Extract correlation ID from request state or headers."""
    if hasattr(request.state, "correlation_id"):
        return request.state.correlation_id
    return request.headers.get("x-correlation-id")


async def app_exception_handler(
    request: Request,
    exc: AppException,
) -> JSONResponse:
    """Handle custom application exceptions."""
    correlation_id = get_correlation_id(request)
    
    error_response = ErrorResponse(
        error=exc.error_code,
        message=exc.message,
        details=exc.details,
        timestamp=datetime.utcnow(),
        correlation_id=correlation_id,
        path=request.url.path,
    )
    
    logger.warning(
        f"AppException: {exc.error_code} - {exc.message}",
        extra={
            "correlation_id": correlation_id,
            "path": request.url.path,
            "status_code": exc.status_code,
        }
    )
    
    headers = {}
    if isinstance(exc, RateLimitError):
        headers["Retry-After"] = str(exc.retry_after)
    
    return JSONResponse(
        status_code=exc.status_code,
        content=error_response.model_dump(mode="json"),
        headers=headers,
    )


async def http_exception_handler(
    request: Request,
    exc: Union[HTTPException, StarletteHTTPException],
) -> JSONResponse:
    """Handle FastAPI/Starlette HTTP exceptions."""
    correlation_id = get_correlation_id(request)
    
    error_response = ErrorResponse(
        error=_status_code_to_error(exc.status_code),
        message=str(exc.detail) if exc.detail else "An error occurred",
        timestamp=datetime.utcnow(),
        correlation_id=correlation_id,
        path=request.url.path,
    )
    
    logger.warning(
        f"HTTPException: {exc.status_code} - {exc.detail}",
        extra={
            "correlation_id": correlation_id,
            "path": request.url.path,
        }
    )
    
    return JSONResponse(
        status_code=exc.status_code,
        content=error_response.model_dump(mode="json"),
    )


async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    """Handle Pydantic validation errors."""
    correlation_id = get_correlation_id(request)
    
    details = []
    for error in exc.errors():
        details.append(ErrorDetail(
            loc=list(error.get("loc", [])),
            msg=error.get("msg", "Validation error"),
            type=error.get("type"),
        ))
    
    error_response = ErrorResponse(
        error="VALIDATION_ERROR",
        message="Request validation failed",
        details=details,
        timestamp=datetime.utcnow(),
        correlation_id=correlation_id,
        path=request.url.path,
    )
    
    logger.warning(
        f"ValidationError: {len(details)} validation errors",
        extra={
            "correlation_id": correlation_id,
            "path": request.url.path,
            "errors": [d.model_dump() for d in details],
        }
    )
    
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=error_response.model_dump(mode="json"),
    )


async def pydantic_validation_exception_handler(
    request: Request,
    exc: ValidationError,
) -> JSONResponse:
    """Handle Pydantic ValidationError (from response models)."""
    correlation_id = get_correlation_id(request)
    
    details = []
    for error in exc.errors():
        details.append(ErrorDetail(
            loc=list(error.get("loc", [])),
            msg=error.get("msg", "Validation error"),
            type=error.get("type"),
        ))
    
    error_response = ErrorResponse(
        error="RESPONSE_VALIDATION_ERROR",
        message="Response validation failed",
        details=details,
        timestamp=datetime.utcnow(),
        correlation_id=correlation_id,
        path=request.url.path,
    )
    
    logger.error(
        f"ResponseValidationError: {len(details)} validation errors",
        extra={
            "correlation_id": correlation_id,
            "path": request.url.path,
        }
    )
    
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=error_response.model_dump(mode="json"),
    )


async def general_exception_handler(
    request: Request,
    exc: Exception,
) -> JSONResponse:
    """Handle unexpected exceptions."""
    correlation_id = get_correlation_id(request)
    
    # Log full traceback
    logger.error(
        f"Unhandled exception: {type(exc).__name__}: {str(exc)}",
        extra={
            "correlation_id": correlation_id,
            "path": request.url.path,
            "traceback": traceback.format_exc(),
        }
    )
    
    error_response = ErrorResponse(
        error="INTERNAL_SERVER_ERROR",
        message="An unexpected error occurred",
        timestamp=datetime.utcnow(),
        correlation_id=correlation_id,
        path=request.url.path,
    )
    
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=error_response.model_dump(mode="json"),
    )


def _status_code_to_error(status_code: int) -> str:
    """Convert HTTP status code to error string."""
    mapping = {
        400: "BAD_REQUEST",
        401: "UNAUTHORIZED",
        403: "FORBIDDEN",
        404: "NOT_FOUND",
        405: "METHOD_NOT_ALLOWED",
        409: "CONFLICT",
        413: "PAYLOAD_TOO_LARGE",
        415: "UNSUPPORTED_MEDIA_TYPE",
        422: "VALIDATION_ERROR",
        429: "RATE_LIMIT_EXCEEDED",
        500: "INTERNAL_SERVER_ERROR",
        502: "BAD_GATEWAY",
        503: "SERVICE_UNAVAILABLE",
        504: "GATEWAY_TIMEOUT",
    }
    return mapping.get(status_code, "ERROR")


# =============================================================================
# Registration
# =============================================================================

def register_exception_handlers(app: FastAPI):
    """Register all exception handlers with the FastAPI app."""
    app.add_exception_handler(AppException, app_exception_handler)
    app.add_exception_handler(HTTPException, http_exception_handler)
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(ValidationError, pydantic_validation_exception_handler)
    app.add_exception_handler(Exception, general_exception_handler)
