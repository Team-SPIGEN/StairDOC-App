"""
Redis caching service for high-throughput data access.

Implements cache-aside pattern with TTL-based expiration.
Supports 1000+ requests/min by caching frequent reads:
- Robot status (5 second TTL for real-time data)
- User sessions (15 minute TTL)
- Delivery queues (30 second TTL)
- Access logs (1 minute TTL for recent entries)
"""

import json
import logging
from datetime import timedelta
from typing import Any, Callable, Optional, TypeVar
from functools import wraps

logger = logging.getLogger(__name__)

T = TypeVar("T")

# Default TTL values in seconds
DEFAULT_TTL = 60
ROBOT_STATUS_TTL = 5  # Real-time robot data
USER_SESSION_TTL = 900  # 15 minutes
DELIVERY_QUEUE_TTL = 30  # Active deliveries
ACCESS_LOG_TTL = 60  # Recent access logs
CAMERA_STREAM_TTL = 10  # Camera sessions


class CacheService:
    """
    In-memory cache with TTL support.
    
    Falls back to local cache if Redis is unavailable.
    Production deployments should use Redis for distributed caching.
    """
    
    def __init__(self, redis_url: Optional[str] = None):
        self._redis = None
        self._local_cache: dict[str, tuple[Any, float]] = {}
        self._redis_url = redis_url
        self._connected = False
        
    async def connect(self) -> bool:
        """Attempt to connect to Redis."""
        if not self._redis_url:
            logger.info("No Redis URL configured, using local cache")
            return False
            
        try:
            import redis.asyncio as aioredis
            self._redis = aioredis.from_url(
                self._redis_url,
                encoding="utf-8",
                decode_responses=True,
                socket_connect_timeout=5,
                socket_timeout=5,
            )
            await self._redis.ping()
            self._connected = True
            logger.info("Connected to Redis cache")
            return True
        except Exception as e:
            logger.warning(f"Redis connection failed, using local cache: {e}")
            self._redis = None
            self._connected = False
            return False
    
    async def disconnect(self) -> None:
        """Close Redis connection."""
        if self._redis:
            await self._redis.close()
            self._redis = None
            self._connected = False
            logger.info("Disconnected from Redis")
    
    @property
    def is_connected(self) -> bool:
        """Check if Redis is connected."""
        return self._connected and self._redis is not None
    
    # =========================================================================
    # Core Cache Operations
    # =========================================================================
    
    async def get(self, key: str) -> Optional[Any]:
        """Get value from cache."""
        try:
            if self._redis:
                value = await self._redis.get(key)
                if value:
                    return json.loads(value)
            else:
                return self._get_local(key)
        except Exception as e:
            logger.error(f"Cache get error for {key}: {e}")
        return None
    
    async def set(
        self, 
        key: str, 
        value: Any, 
        ttl: int = DEFAULT_TTL,
    ) -> bool:
        """Set value in cache with TTL."""
        try:
            serialized = json.dumps(value, default=str)
            if self._redis:
                await self._redis.setex(key, ttl, serialized)
            else:
                self._set_local(key, value, ttl)
            return True
        except Exception as e:
            logger.error(f"Cache set error for {key}: {e}")
            return False
    
    async def delete(self, key: str) -> bool:
        """Delete value from cache."""
        try:
            if self._redis:
                await self._redis.delete(key)
            else:
                self._local_cache.pop(key, None)
            return True
        except Exception as e:
            logger.error(f"Cache delete error for {key}: {e}")
            return False
    
    async def delete_pattern(self, pattern: str) -> int:
        """Delete all keys matching pattern."""
        try:
            if self._redis:
                keys = await self._redis.keys(pattern)
                if keys:
                    return await self._redis.delete(*keys)
            else:
                # Local cache pattern matching
                import fnmatch
                deleted = 0
                keys_to_delete = [
                    k for k in self._local_cache.keys()
                    if fnmatch.fnmatch(k, pattern)
                ]
                for k in keys_to_delete:
                    self._local_cache.pop(k, None)
                    deleted += 1
                return deleted
        except Exception as e:
            logger.error(f"Cache delete pattern error for {pattern}: {e}")
        return 0
    
    async def exists(self, key: str) -> bool:
        """Check if key exists in cache."""
        try:
            if self._redis:
                return await self._redis.exists(key) > 0
            else:
                return self._get_local(key) is not None
        except Exception:
            return False
    
    # =========================================================================
    # Local Cache Implementation
    # =========================================================================
    
    def _get_local(self, key: str) -> Optional[Any]:
        """Get from local cache with TTL check."""
        import time
        if key in self._local_cache:
            value, expiry = self._local_cache[key]
            if time.time() < expiry:
                return value
            else:
                del self._local_cache[key]
        return None
    
    def _set_local(self, key: str, value: Any, ttl: int) -> None:
        """Set in local cache with TTL."""
        import time
        self._local_cache[key] = (value, time.time() + ttl)
        
        # Cleanup expired entries periodically
        if len(self._local_cache) > 1000:
            self._cleanup_local()
    
    def _cleanup_local(self) -> None:
        """Remove expired entries from local cache."""
        import time
        now = time.time()
        expired = [k for k, (_, exp) in self._local_cache.items() if now >= exp]
        for k in expired:
            del self._local_cache[k]
    
    # =========================================================================
    # Domain-Specific Cache Keys
    # =========================================================================
    
    @staticmethod
    def robot_status_key(robot_id: str) -> str:
        return f"robot:status:{robot_id}"
    
    @staticmethod
    def robot_list_key() -> str:
        return "robot:list"
    
    @staticmethod
    def user_session_key(user_id: str) -> str:
        return f"user:session:{user_id}"
    
    @staticmethod
    def delivery_queue_key(robot_id: Optional[str] = None) -> str:
        if robot_id:
            return f"delivery:queue:{robot_id}"
        return "delivery:queue:all"
    
    @staticmethod
    def delivery_job_key(job_id: str) -> str:
        return f"delivery:job:{job_id}"
    
    @staticmethod
    def access_log_key(user_id: Optional[str] = None) -> str:
        if user_id:
            return f"access:log:{user_id}"
        return "access:log:recent"
    
    @staticmethod
    def camera_session_key(session_id: str) -> str:
        return f"camera:session:{session_id}"
    
    # =========================================================================
    # Cache-Aside Pattern Helpers
    # =========================================================================
    
    async def get_or_set(
        self,
        key: str,
        factory: Callable[[], Any],
        ttl: int = DEFAULT_TTL,
    ) -> Any:
        """
        Get from cache, or compute and cache if missing.
        
        Implements cache-aside pattern:
        1. Check cache for key
        2. If hit, return cached value
        3. If miss, call factory to get value
        4. Cache the result with TTL
        5. Return the value
        """
        value = await self.get(key)
        if value is not None:
            return value
        
        # Cache miss - compute value
        if callable(factory):
            import asyncio
            if asyncio.iscoroutinefunction(factory):
                value = await factory()
            else:
                value = factory()
        else:
            value = factory
        
        if value is not None:
            await self.set(key, value, ttl)
        
        return value
    
    # =========================================================================
    # Cache Statistics
    # =========================================================================
    
    async def get_stats(self) -> dict[str, Any]:
        """Get cache statistics."""
        stats = {
            "backend": "redis" if self._redis else "local",
            "connected": self._connected,
        }
        
        try:
            if self._redis:
                info = await self._redis.info("stats")
                stats.update({
                    "hits": info.get("keyspace_hits", 0),
                    "misses": info.get("keyspace_misses", 0),
                    "keys": await self._redis.dbsize(),
                })
            else:
                stats.update({
                    "keys": len(self._local_cache),
                    "memory_usage": "local",
                })
        except Exception as e:
            stats["error"] = str(e)
        
        return stats


# Global cache instance
_cache: Optional[CacheService] = None


def get_cache() -> CacheService:
    """Get the global cache service instance."""
    global _cache
    if _cache is None:
        from .config import get_settings
        settings = get_settings()
        redis_url = getattr(settings, "redis_url", None)
        _cache = CacheService(redis_url)
    return _cache


async def init_cache() -> CacheService:
    """Initialize the cache service."""
    cache = get_cache()
    await cache.connect()
    return cache


async def close_cache() -> None:
    """Close the cache service."""
    global _cache
    if _cache:
        await _cache.disconnect()
        _cache = None


# =========================================================================
# Caching Decorator
# =========================================================================

def cached(
    key_prefix: str,
    ttl: int = DEFAULT_TTL,
    key_builder: Optional[Callable[..., str]] = None,
):
    """
    Decorator for caching function results.
    
    Usage:
        @cached("robot:status", ttl=5)
        async def get_robot_status(robot_id: str):
            ...
    """
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @wraps(func)
        async def wrapper(*args, **kwargs) -> T:
            cache = get_cache()
            
            # Build cache key
            if key_builder:
                cache_key = key_builder(*args, **kwargs)
            else:
                # Default key: prefix + args
                key_parts = [key_prefix]
                key_parts.extend(str(a) for a in args)
                key_parts.extend(f"{k}={v}" for k, v in sorted(kwargs.items()))
                cache_key = ":".join(key_parts)
            
            # Try cache first
            cached_value = await cache.get(cache_key)
            if cached_value is not None:
                return cached_value
            
            # Cache miss - call function
            result = await func(*args, **kwargs)
            
            # Cache result
            if result is not None:
                await cache.set(cache_key, result, ttl)
            
            return result
        
        return wrapper
    return decorator
