"""
StairDOC API - Main application entry point.

Features:
- High throughput (1000+ requests/min) with connection pooling & caching
- Request validation, rate limiting, and comprehensive logging
- Security headers and input sanitization
- Structured error handling with correlation IDs
"""

import logging
import sys
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from .api import access, auth, camera, delivery, health, notifications, robot, voice, websocket
from .core.config import get_settings
from .core.database import init_db, close_db
from .core.cache import init_cache, close_cache
from .core.rate_limit import RateLimitMiddleware
from .core.logging import RequestLoggingMiddleware, setup_logging
from .core.middleware import SecurityHeadersMiddleware, RequestValidationMiddleware
from .core.exceptions import register_exception_handlers

settings = get_settings()

# Configure structured logging
setup_logging(
    level=settings.log_level,
    format_type=settings.log_format,
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager for startup and shutdown."""
    # Startup
    logger.info(
        "Starting StairDOC API",
        extra={
            "app_name": settings.app_name,
            "version": settings.app_version,
            "debug": settings.debug,
        }
    )
    await init_db()
    logger.info("Database initialized")
    
    await init_cache()
    logger.info("Cache initialized")
    
    yield
    
    # Shutdown
    logger.info("Shutting down StairDOC API...")
    await close_cache()
    await close_db()
    logger.info("Shutdown complete")


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    lifespan=lifespan,
)

# Register exception handlers for consistent error responses
register_exception_handlers(app)


# =============================================================================
# Middleware Stack (order matters - executed in reverse order)
# =============================================================================

# 1. Request timing middleware (innermost - measures actual processing time)
@app.middleware("http")
async def add_request_timing(request: Request, call_next):
    """Add request timing header for performance monitoring."""
    start_time = time.perf_counter()
    response = await call_next(request)
    process_time = (time.perf_counter() - start_time) * 1000
    response.headers["X-Process-Time-Ms"] = f"{process_time:.2f}"
    
    # Log slow requests (> 500ms)
    if process_time > 500:
        logger.warning(
            f"Slow request: {request.method} {request.url.path} took {process_time:.2f}ms",
            extra={
                "path": request.url.path,
                "method": request.method,
                "duration_ms": process_time,
            }
        )
    
    return response


# 2. Request logging middleware (logs all requests with correlation IDs)
app.add_middleware(
    RequestLoggingMiddleware,
    log_request_body=settings.log_request_body,
    log_response_body=settings.log_response_body,
)

# 3. Rate limiting middleware (protects against abuse)
if settings.rate_limit_enabled:
    app.add_middleware(
        RateLimitMiddleware,
        default_requests=settings.rate_limit_requests_per_minute,
        default_window=60,
        default_burst=settings.rate_limit_burst,
    )

# 4. Request validation middleware (validates content-type and size)
app.add_middleware(
    RequestValidationMiddleware,
    max_body_size=settings.max_request_size,
)

# 5. Security headers middleware (adds security headers to responses)
app.add_middleware(SecurityHeadersMiddleware)

# 6. CORS middleware (handles cross-origin requests)
if settings.allowed_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.allowed_origins),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


# =============================================================================
# API Routers
# =============================================================================

app.include_router(health.router)
app.include_router(auth.router, prefix=settings.api_v1_prefix)
app.include_router(robot.router, prefix=settings.api_v1_prefix)
app.include_router(delivery.router, prefix=settings.api_v1_prefix)
app.include_router(access.router, prefix=settings.api_v1_prefix)
app.include_router(voice.router, prefix=settings.api_v1_prefix)
app.include_router(notifications.router, prefix=settings.api_v1_prefix)
app.include_router(camera.router, prefix=settings.api_v1_prefix)
app.include_router(websocket.router, prefix=settings.api_v1_prefix)


# =============================================================================
# Development Info
# =============================================================================

@app.on_event("startup")
async def log_startup_info():
    """Log application configuration on startup."""
    logger.info(
        "Application configuration",
        extra={
            "rate_limiting": settings.rate_limit_enabled,
            "log_level": settings.log_level,
            "log_format": settings.log_format,
            "max_request_size": settings.max_request_size,
            "db_pool_size": settings.db_pool_size,
            "redis_enabled": settings.redis_url is not None,
        }
    )
