"""
Database configuration with optimized connection pooling for high throughput.

Supports 1000+ requests/min with:
- Async connection pooling (pool_size=20, max_overflow=30)
- Connection recycling every 30 minutes
- Pre-ping to validate connections
- Query execution timing and slow query logging
"""

import logging
import time
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from typing import Any

from sqlmodel import SQLModel
from sqlmodel.ext.asyncio.session import AsyncSession
from sqlalchemy import event, text
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine
from sqlalchemy.pool import AsyncAdaptedQueuePool

from .config import get_settings

logger = logging.getLogger(__name__)

_settings = get_settings()

# Connection pool configuration for high throughput
# Target: 1000+ requests/min = ~17 requests/sec
_pool_config = {
    "pool_size": 20,  # Concurrent connections
    "max_overflow": 30,  # Extra connections under load
    "pool_timeout": 30,  # Wait time for connection
    "pool_recycle": 1800,  # Recycle connections every 30 min
    "pool_pre_ping": True,  # Validate connections before use
}

# SQLite uses NullPool by default, PostgreSQL uses QueuePool
if "sqlite" in _settings.database_url:
    # SQLite: Limited connection pooling, but enable WAL mode for concurrency
    _engine: AsyncEngine = create_async_engine(
        _settings.database_url,
        echo=False,
        connect_args={"check_same_thread": False},
    )
else:
    # PostgreSQL/MySQL: Full connection pooling
    _engine: AsyncEngine = create_async_engine(
        _settings.database_url,
        echo=False,
        poolclass=AsyncAdaptedQueuePool,
        **_pool_config,
    )

# Query timing storage for slow query detection
_query_start_times: dict[int, float] = {}
SLOW_QUERY_THRESHOLD_MS = 100  # Log queries taking > 100ms


def _before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    """Record query start time."""
    _query_start_times[id(cursor)] = time.perf_counter()


def _after_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    """Log slow queries."""
    start_time = _query_start_times.pop(id(cursor), None)
    if start_time:
        elapsed_ms = (time.perf_counter() - start_time) * 1000
        if elapsed_ms > SLOW_QUERY_THRESHOLD_MS:
            logger.warning(
                f"Slow query ({elapsed_ms:.2f}ms): {statement[:200]}..."
                if len(statement) > 200 else f"Slow query ({elapsed_ms:.2f}ms): {statement}"
            )


# Register query timing events
event.listen(_engine.sync_engine, "before_cursor_execute", _before_cursor_execute)
event.listen(_engine.sync_engine, "after_cursor_execute", _after_cursor_execute)


async def init_db() -> None:
    """Initialize database tables and enable optimizations."""
    # Import all models to ensure they are registered with SQLModel metadata
    from ..models.user import User  # noqa: F401
    from ..models.robot_unit import RobotUnit  # noqa: F401
    from ..models.delivery_job import DeliveryJob  # noqa: F401
    from ..models.access_log import AccessLog  # noqa: F401
    
    async with _engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.create_all)
        
        # Enable SQLite optimizations if using SQLite
        if "sqlite" in _settings.database_url:
            await conn.execute(text("PRAGMA journal_mode=WAL"))
            await conn.execute(text("PRAGMA synchronous=NORMAL"))
            await conn.execute(text("PRAGMA cache_size=10000"))
            await conn.execute(text("PRAGMA temp_store=MEMORY"))
            logger.info("SQLite optimizations enabled (WAL mode, cache, temp store)")


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """Get an async database session with auto-commit on success."""
    async_session = AsyncSession(_engine, expire_on_commit=False)
    try:
        yield async_session
        await async_session.commit()
    except Exception:
        await async_session.rollback()
        raise
    finally:
        await async_session.close()


@asynccontextmanager
async def get_session_context() -> AsyncGenerator[AsyncSession, None]:
    """Context manager for database sessions (for non-dependency use)."""
    async_session = AsyncSession(_engine, expire_on_commit=False)
    try:
        yield async_session
        await async_session.commit()
    except Exception:
        await async_session.rollback()
        raise
    finally:
        await async_session.close()


async def get_pool_status() -> dict[str, Any]:
    """Get connection pool statistics for monitoring."""
    pool = _engine.pool
    return {
        "pool_size": getattr(pool, "size", lambda: 0)() if callable(getattr(pool, "size", None)) else 0,
        "checked_in": pool.checkedin(),
        "checked_out": pool.checkedout(),
        "overflow": pool.overflow(),
        "invalid": pool.invalidatedcount() if hasattr(pool, "invalidatedcount") else 0,
    }


async def health_check() -> dict[str, Any]:
    """Check database connectivity and return health status."""
    start = time.perf_counter()
    try:
        async with _engine.begin() as conn:
            result = await conn.execute(text("SELECT 1"))
            result.fetchone()
        latency_ms = (time.perf_counter() - start) * 1000
        pool_status = await get_pool_status()
        return {
            "status": "healthy",
            "latency_ms": round(latency_ms, 2),
            "pool": pool_status,
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e),
        }


async def close_db() -> None:
    """Close database connections gracefully."""
    await _engine.dispose()
    logger.info("Database connections closed")

