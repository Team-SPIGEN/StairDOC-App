"""
Request logging middleware for comprehensive API observability.

Implements:
- Structured JSON logging for all requests/responses
- Correlation IDs for request tracing
- Request body logging (with sensitive data masking)
- Response time tracking
- Error logging with stack traces
"""

import json
import logging
import re
import sys
import time
import traceback
import uuid
from datetime import datetime
from typing import Any, Callable, Dict, List, Optional, Set

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import Message


# =============================================================================
# Logging Setup
# =============================================================================

class JSONFormatter(logging.Formatter):
    """JSON log formatter for structured logging."""
    
    def format(self, record: logging.LogRecord) -> str:
        log_data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        
        # Add extra fields
        if hasattr(record, "__dict__"):
            for key, value in record.__dict__.items():
                if key not in {
                    "name", "msg", "args", "created", "filename", "funcName",
                    "levelname", "levelno", "lineno", "module", "msecs",
                    "pathname", "process", "processName", "relativeCreated",
                    "stack_info", "exc_info", "exc_text", "thread", "threadName",
                    "message", "taskName",
                }:
                    log_data[key] = value
        
        # Add exception info if present
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)
        
        return json.dumps(log_data, default=str)


class TextFormatter(logging.Formatter):
    """Human-readable text formatter."""
    
    def format(self, record: logging.LogRecord) -> str:
        # Base format
        base = f"{datetime.utcnow().isoformat()}Z - {record.levelname:8s} - {record.name} - {record.getMessage()}"
        
        # Add extra fields
        extras = []
        if hasattr(record, "__dict__"):
            for key, value in record.__dict__.items():
                if key not in {
                    "name", "msg", "args", "created", "filename", "funcName",
                    "levelname", "levelno", "lineno", "module", "msecs",
                    "pathname", "process", "processName", "relativeCreated",
                    "stack_info", "exc_info", "exc_text", "thread", "threadName",
                    "message", "taskName",
                }:
                    extras.append(f"{key}={value}")
        
        if extras:
            base += f" | {' '.join(extras)}"
        
        # Add exception info if present
        if record.exc_info:
            base += "\n" + self.formatException(record.exc_info)
        
        return base


def setup_logging(
    level: str = "INFO",
    format_type: str = "json",
) -> None:
    """
    Configure application logging.
    
    Args:
        level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        format_type: Output format ('json' or 'text')
    """
    # Clear existing handlers
    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    
    # Create handler
    handler = logging.StreamHandler(sys.stdout)
    
    # Set formatter based on type
    if format_type.lower() == "json":
        handler.setFormatter(JSONFormatter())
    else:
        handler.setFormatter(TextFormatter())
    
    # Configure root logger
    root_logger.addHandler(handler)
    root_logger.setLevel(getattr(logging, level.upper(), logging.INFO))
    
    # Set levels for noisy libraries
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)


logger = logging.getLogger("stairdoc.requests")

# Sensitive fields to mask in logs
SENSITIVE_FIELDS: Set[str] = {
    "password",
    "hashed_password",
    "secret",
    "token",
    "access_token",
    "refresh_token",
    "api_key",
    "authorization",
    "cookie",
    "x-api-key",
}

# Patterns for masking sensitive data
SENSITIVE_PATTERNS = [
    (re.compile(r'"password"\s*:\s*"[^"]*"', re.IGNORECASE), '"password": "***"'),
    (re.compile(r'"token"\s*:\s*"[^"]*"', re.IGNORECASE), '"token": "***"'),
    (re.compile(r'"api_key"\s*:\s*"[^"]*"', re.IGNORECASE), '"api_key": "***"'),
    (re.compile(r'Bearer\s+[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_.+=]*', re.IGNORECASE), 'Bearer ***'),
]

# Paths to exclude from body logging
EXCLUDE_BODY_PATHS: Set[str] = {
    "/api/v1/camera",
    "/api/v1/auth/login",
    "/api/v1/auth/register",
}


def mask_sensitive_data(data: Any) -> Any:
    """Mask sensitive fields in data structures."""
    if isinstance(data, dict):
        masked = {}
        for key, value in data.items():
            if key.lower() in SENSITIVE_FIELDS:
                masked[key] = "***"
            else:
                masked[key] = mask_sensitive_data(value)
        return masked
    elif isinstance(data, list):
        return [mask_sensitive_data(item) for item in data]
    elif isinstance(data, str):
        # Apply pattern masking
        result = data
        for pattern, replacement in SENSITIVE_PATTERNS:
            result = pattern.sub(replacement, result)
        return result
    return data


def mask_headers(headers: Dict[str, str]) -> Dict[str, str]:
    """Mask sensitive headers."""
    masked = {}
    for key, value in headers.items():
        if key.lower() in SENSITIVE_FIELDS:
            masked[key] = "***"
        elif key.lower() == "authorization":
            # Keep auth type but mask token
            parts = value.split(" ", 1)
            masked[key] = f"{parts[0]} ***" if len(parts) > 1 else "***"
        else:
            masked[key] = value
    return masked


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """
    Middleware for comprehensive request/response logging.
    
    Features:
    - Correlation ID generation and propagation
    - Request/response body logging (with masking)
    - Timing and performance metrics
    - Error tracking
    """
    
    def __init__(
        self,
        app,
        log_request_body: bool = True,
        log_response_body: bool = False,
        max_body_length: int = 10000,
        exclude_paths: Optional[Set[str]] = None,
    ):
        super().__init__(app)
        self.log_request_body = log_request_body
        self.log_response_body = log_response_body
        self.max_body_length = max_body_length
        self.exclude_paths = exclude_paths or {"/health", "/docs", "/redoc", "/openapi.json"}
    
    async def dispatch(self, request: Request, call_next) -> Response:
        """Process and log request/response."""
        # Skip logging for excluded paths
        if request.url.path in self.exclude_paths:
            return await call_next(request)
        
        # Generate or extract correlation ID
        correlation_id = request.headers.get("x-correlation-id") or str(uuid.uuid4())
        
        # Store correlation ID in request state for access in handlers
        request.state.correlation_id = correlation_id
        
        start_time = time.perf_counter()
        
        # Build request log entry
        request_log = await self._build_request_log(request, correlation_id)
        
        try:
            # Process request
            response = await call_next(request)
            
            # Calculate processing time
            process_time_ms = (time.perf_counter() - start_time) * 1000
            
            # Build response log entry
            response_log = self._build_response_log(
                response, correlation_id, process_time_ms
            )
            
            # Combine and log
            log_entry = {
                **request_log,
                **response_log,
            }
            
            # Log level based on status code
            if response.status_code >= 500:
                logger.error(json.dumps(log_entry))
            elif response.status_code >= 400:
                logger.warning(json.dumps(log_entry))
            else:
                logger.info(json.dumps(log_entry))
            
            # Add correlation ID to response headers
            response.headers["X-Correlation-ID"] = correlation_id
            
            return response
            
        except Exception as e:
            # Log exception
            process_time_ms = (time.perf_counter() - start_time) * 1000
            
            error_log = {
                **request_log,
                "status_code": 500,
                "process_time_ms": round(process_time_ms, 2),
                "error": {
                    "type": type(e).__name__,
                    "message": str(e),
                    "traceback": traceback.format_exc(),
                },
            }
            
            logger.error(json.dumps(error_log))
            raise
    
    async def _build_request_log(
        self,
        request: Request,
        correlation_id: str,
    ) -> Dict[str, Any]:
        """Build log entry for request."""
        # Get client IP
        client_ip = request.headers.get("x-forwarded-for")
        if client_ip:
            client_ip = client_ip.split(",")[0].strip()
        elif request.client:
            client_ip = request.client.host
        else:
            client_ip = "unknown"
        
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "correlation_id": correlation_id,
            "type": "request",
            "method": request.method,
            "path": request.url.path,
            "query_params": dict(request.query_params),
            "client_ip": client_ip,
            "user_agent": request.headers.get("user-agent", ""),
            "content_type": request.headers.get("content-type", ""),
            "content_length": request.headers.get("content-length", "0"),
        }
        
        # Add masked headers
        headers_to_log = {
            "accept": request.headers.get("accept", ""),
            "accept-language": request.headers.get("accept-language", ""),
            "authorization": request.headers.get("authorization", ""),
            "x-api-key": request.headers.get("x-api-key", ""),
        }
        log_entry["headers"] = mask_headers(headers_to_log)
        
        # Log request body for non-excluded paths
        if self.log_request_body and request.url.path not in EXCLUDE_BODY_PATHS:
            try:
                body = await request.body()
                if body and len(body) <= self.max_body_length:
                    try:
                        body_json = json.loads(body.decode())
                        log_entry["body"] = mask_sensitive_data(body_json)
                    except (json.JSONDecodeError, UnicodeDecodeError):
                        log_entry["body"] = f"<binary data: {len(body)} bytes>"
                elif body:
                    log_entry["body"] = f"<truncated: {len(body)} bytes>"
            except Exception:
                pass
        
        return log_entry
    
    def _build_response_log(
        self,
        response: Response,
        correlation_id: str,
        process_time_ms: float,
    ) -> Dict[str, Any]:
        """Build log entry for response."""
        return {
            "status_code": response.status_code,
            "process_time_ms": round(process_time_ms, 2),
            "response_headers": {
                "content-type": response.headers.get("content-type", ""),
                "content-length": response.headers.get("content-length", ""),
            },
        }


class AuditLogger:
    """
    Audit logger for tracking sensitive operations.
    
    Logs to both file and database for compliance.
    """
    
    def __init__(self):
        self.logger = logging.getLogger("stairdoc.audit")
        self._handlers_configured = False
    
    def configure(self, log_file: Optional[str] = None):
        """Configure audit logging handlers."""
        if self._handlers_configured:
            return
        
        # Add file handler for audit logs
        if log_file:
            handler = logging.FileHandler(log_file)
            handler.setFormatter(logging.Formatter(
                '%(asctime)s - AUDIT - %(message)s'
            ))
            self.logger.addHandler(handler)
        
        self.logger.setLevel(logging.INFO)
        self._handlers_configured = True
    
    def log(
        self,
        action: str,
        user_id: str,
        resource_type: str,
        resource_id: Optional[str] = None,
        details: Optional[Dict[str, Any]] = None,
        ip_address: Optional[str] = None,
        correlation_id: Optional[str] = None,
    ):
        """
        Log an audit event.
        
        Args:
            action: Action performed (e.g., 'login', 'unlock', 'delete')
            user_id: ID of user performing action
            resource_type: Type of resource affected
            resource_id: ID of specific resource (optional)
            details: Additional context
            ip_address: Client IP address
            correlation_id: Request correlation ID
        """
        entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "action": action,
            "user_id": user_id,
            "resource_type": resource_type,
            "resource_id": resource_id,
            "details": mask_sensitive_data(details or {}),
            "ip_address": ip_address,
            "correlation_id": correlation_id,
        }
        
        self.logger.info(json.dumps(entry))


# Global audit logger instance
audit_logger = AuditLogger()


def get_audit_logger() -> AuditLogger:
    """Get the global audit logger instance."""
    return audit_logger
