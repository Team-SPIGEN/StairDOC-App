"""
StairDOC API - Main application entry point.

Optimized for high throughput (1000+ requests/min) with:
- Connection pooling
- Redis caching
- Query optimization
"""

import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from .api import access, auth, camera, delivery, health, notifications, robot, voice, websocket
from .core.config import get_settings
from .core.database import init_db, close_db
from .core.cache import init_cache, close_cache

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager for startup and shutdown."""
    # Startup
    logger.info("Starting StairDOC API...")
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
    lifespan=lifespan,
)


# Request timing middleware for performance monitoring
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
            f"Slow request: {request.method} {request.url.path} took {process_time:.2f}ms"
        )
    
    return response


if settings.allowed_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.allowed_origins),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


app.include_router(health.router)
app.include_router(auth.router, prefix=settings.api_v1_prefix)
app.include_router(robot.router, prefix=settings.api_v1_prefix)
app.include_router(delivery.router, prefix=settings.api_v1_prefix)
app.include_router(access.router, prefix=settings.api_v1_prefix)
app.include_router(voice.router, prefix=settings.api_v1_prefix)
app.include_router(notifications.router, prefix=settings.api_v1_prefix)
app.include_router(camera.router, prefix=settings.api_v1_prefix)
app.include_router(websocket.router, prefix=settings.api_v1_prefix)
