"""
Database health and performance monitoring API.

Provides endpoints for:
- Connection pool status
- Query performance metrics
- Cache statistics
- Load testing
"""

import asyncio
import time
from datetime import datetime
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from ..core.database import (
    get_session,
    get_session_context,
    health_check as db_health_check,
    get_pool_status,
)
from ..core.cache import get_cache, CacheService, ROBOT_STATUS_TTL, DELIVERY_QUEUE_TTL

router = APIRouter(tags=["Health & Monitoring"])


# =============================================================================
# Response Models
# =============================================================================

class HealthResponse(BaseModel):
    status: str
    timestamp: datetime
    database: dict[str, Any]
    cache: dict[str, Any]
    uptime_seconds: float


class PoolStatusResponse(BaseModel):
    pool_size: int
    checked_in: int
    checked_out: int
    overflow: int
    invalid: int


class CacheStatsResponse(BaseModel):
    backend: str
    connected: bool
    keys: int
    hits: Optional[int] = None
    misses: Optional[int] = None
    hit_rate: Optional[float] = None


class LoadTestResult(BaseModel):
    total_requests: int
    successful_requests: int
    failed_requests: int
    total_time_ms: float
    avg_latency_ms: float
    min_latency_ms: float
    max_latency_ms: float
    requests_per_second: float
    p50_latency_ms: float
    p95_latency_ms: float
    p99_latency_ms: float


# Track server start time for uptime
_start_time = time.time()


# =============================================================================
# Health Endpoints
# =============================================================================

@router.get("/health")
async def simple_health_check():
    """Simple health check for load balancers."""
    return {"status": "ok"}


@router.get("/health/detailed", response_model=HealthResponse)
async def get_detailed_health():
    """
    Get overall system health status.
    
    Returns database and cache health along with uptime.
    """
    db_health = await db_health_check()
    cache = get_cache()
    cache_stats = await cache.get_stats()
    
    return HealthResponse(
        status="healthy" if db_health["status"] == "healthy" else "degraded",
        timestamp=datetime.utcnow(),
        database=db_health,
        cache=cache_stats,
        uptime_seconds=time.time() - _start_time,
    )


@router.get("/health/database", response_model=dict[str, Any])
async def get_database_health():
    """
    Get detailed database health status.
    
    Includes connection pool metrics and query latency.
    """
    return await db_health_check()


@router.get("/health/database/pool", response_model=PoolStatusResponse)
async def get_pool_metrics():
    """
    Get connection pool status.
    
    Monitor pool utilization to ensure adequate capacity for 1000+ req/min.
    """
    status = await get_pool_status()
    return PoolStatusResponse(**status)


@router.get("/health/cache", response_model=CacheStatsResponse)
async def get_cache_health():
    """
    Get cache statistics.
    
    Monitor cache hit rate and key count.
    """
    cache = get_cache()
    stats = await cache.get_stats()
    
    response = CacheStatsResponse(
        backend=stats.get("backend", "unknown"),
        connected=stats.get("connected", False),
        keys=stats.get("keys", 0),
    )
    
    hits = stats.get("hits")
    misses = stats.get("misses")
    if hits is not None and misses is not None:
        response.hits = hits
        response.misses = misses
        total = hits + misses
        response.hit_rate = round(hits / total * 100, 2) if total > 0 else 0.0
    
    return response


# =============================================================================
# Performance Testing
# =============================================================================

@router.post("/health/load-test", response_model=LoadTestResult)
async def run_load_test(
    requests: int = Query(default=100, ge=10, le=10000, description="Number of requests"),
    concurrency: int = Query(default=10, ge=1, le=100, description="Concurrent requests"),
):
    """
    Run a simple load test against the database.
    
    Executes concurrent SELECT queries to measure throughput.
    Target: 1000+ requests/min = ~17 requests/sec minimum.
    
    **Warning**: Use with caution in production.
    """
    from sqlalchemy import text
    
    latencies: list[float] = []
    errors = 0
    
    async def single_request() -> Optional[float]:
        """Execute a single test query and return latency."""
        nonlocal errors
        start = time.perf_counter()
        try:
            async with get_session_context() as sess:
                result = await sess.execute(text("SELECT 1"))
                result.fetchone()
            return (time.perf_counter() - start) * 1000
        except Exception:
            errors += 1
            return None
    
    # Run load test
    start_time = time.perf_counter()
    
    # Execute in batches for controlled concurrency
    for batch_start in range(0, requests, concurrency):
        batch_size = min(concurrency, requests - batch_start)
        tasks = [single_request() for _ in range(batch_size)]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        for result in results:
            if isinstance(result, float):
                latencies.append(result)
            elif result is None:
                pass  # Error already counted
            else:
                errors += 1
    
    total_time = (time.perf_counter() - start_time) * 1000
    
    # Calculate statistics
    if latencies:
        sorted_latencies = sorted(latencies)
        avg_latency = sum(latencies) / len(latencies)
        min_latency = min(latencies)
        max_latency = max(latencies)
        
        def percentile(data: list[float], p: float) -> float:
            idx = int(len(data) * p / 100)
            return data[min(idx, len(data) - 1)]
        
        p50 = percentile(sorted_latencies, 50)
        p95 = percentile(sorted_latencies, 95)
        p99 = percentile(sorted_latencies, 99)
    else:
        avg_latency = min_latency = max_latency = p50 = p95 = p99 = 0
    
    rps = (requests - errors) / (total_time / 1000) if total_time > 0 else 0
    
    return LoadTestResult(
        total_requests=requests,
        successful_requests=len(latencies),
        failed_requests=errors,
        total_time_ms=round(total_time, 2),
        avg_latency_ms=round(avg_latency, 3),
        min_latency_ms=round(min_latency, 3),
        max_latency_ms=round(max_latency, 3),
        requests_per_second=round(rps, 2),
        p50_latency_ms=round(p50, 3),
        p95_latency_ms=round(p95, 3),
        p99_latency_ms=round(p99, 3),
    )


@router.post("/health/cache/clear")
async def clear_cache(
    pattern: str = Query(default="*", description="Key pattern to clear"),
):
    """
    Clear cache entries matching pattern.
    
    Use '*' to clear all entries.
    """
    cache = get_cache()
    deleted = await cache.delete_pattern(pattern)
    return {"deleted": deleted, "pattern": pattern}


@router.post("/health/cache/warmup")
async def warmup_cache(
    session: AsyncSession = Depends(get_session),
):
    """
    Pre-populate cache with frequently accessed data.
    
    Loads robots and pending deliveries into cache.
    """
    from ..models.robot_unit import RobotUnit
    from ..models.delivery_job import DeliveryJob
    
    cache = get_cache()
    cached_count = 0
    
    # Cache all robots
    result = await session.execute(select(RobotUnit))
    robots = result.scalars().all()
    for robot in robots:
        key = cache.robot_status_key(robot.id)
        await cache.set(key, robot.model_dump(), ROBOT_STATUS_TTL)
        cached_count += 1
    
    # Cache robot list
    robot_list = [r.model_dump() for r in robots]
    await cache.set(cache.robot_list_key(), robot_list, ROBOT_STATUS_TTL)
    cached_count += 1
    
    # Cache pending deliveries
    result = await session.execute(
        select(DeliveryJob).where(DeliveryJob.status.in_(["pending", "in_progress"]))
    )
    jobs = result.scalars().all()
    job_list = [j.model_dump() for j in jobs]
    await cache.set(cache.delivery_queue_key(), job_list, DELIVERY_QUEUE_TTL)
    cached_count += 1
    
    return {
        "cached_entries": cached_count,
        "robots": len(robots),
        "pending_deliveries": len(jobs),
    }

