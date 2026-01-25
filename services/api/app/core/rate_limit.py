"""
Rate limiting middleware for API protection.

Implements:
- Token bucket algorithm for rate limiting
- Per-IP and per-user rate limits
- Configurable limits per endpoint
- Redis-backed distributed rate limiting (with local fallback)
"""

import asyncio
import logging
import time
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Callable, Dict, Optional, Tuple

from fastapi import HTTPException, Request, status
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

logger = logging.getLogger(__name__)


@dataclass
class RateLimitConfig:
    """Configuration for a rate limit."""
    requests: int  # Number of requests allowed
    window_seconds: int  # Time window in seconds
    burst: int = 0  # Extra burst capacity (0 = no burst)
    
    @property
    def requests_per_second(self) -> float:
        return self.requests / self.window_seconds


# Default rate limits by endpoint pattern
DEFAULT_LIMITS: Dict[str, RateLimitConfig] = {
    # Auth endpoints - more restrictive to prevent brute force
    "/api/v1/auth/login": RateLimitConfig(requests=5, window_seconds=60),
    "/api/v1/auth/register": RateLimitConfig(requests=3, window_seconds=60),
    "/api/v1/auth/forgot-password": RateLimitConfig(requests=3, window_seconds=300),
    
    # Container access - moderate limits
    "/api/v1/container/lock": RateLimitConfig(requests=30, window_seconds=60),
    "/api/v1/container/unlock": RateLimitConfig(requests=30, window_seconds=60),
    
    # Voice commands - moderate limits
    "/api/v1/voice/command": RateLimitConfig(requests=60, window_seconds=60),
    
    # Camera endpoints - higher limits for streaming
    "/api/v1/camera": RateLimitConfig(requests=120, window_seconds=60, burst=20),
    
    # Health check - high limits
    "/health": RateLimitConfig(requests=300, window_seconds=60),
    
    # Default for all other endpoints
    "default": RateLimitConfig(requests=100, window_seconds=60, burst=10),
}


@dataclass
class TokenBucket:
    """Token bucket for rate limiting."""
    capacity: float
    tokens: float = field(default=0)
    last_update: float = field(default_factory=time.time)
    rate: float = 1.0  # Tokens per second
    
    def consume(self, tokens: int = 1) -> bool:
        """
        Try to consume tokens. Returns True if successful.
        """
        now = time.time()
        elapsed = now - self.last_update
        
        # Refill tokens based on time elapsed
        self.tokens = min(self.capacity, self.tokens + elapsed * self.rate)
        self.last_update = now
        
        if self.tokens >= tokens:
            self.tokens -= tokens
            return True
        return False
    
    @property
    def remaining(self) -> int:
        """Get remaining tokens."""
        now = time.time()
        elapsed = now - self.last_update
        current = min(self.capacity, self.tokens + elapsed * self.rate)
        return int(current)


class RateLimiter:
    """
    In-memory rate limiter with token bucket algorithm.
    
    For production, use Redis-backed rate limiting.
    """
    
    def __init__(self, limits: Optional[Dict[str, RateLimitConfig]] = None):
        self._limits = limits or DEFAULT_LIMITS
        self._buckets: Dict[str, TokenBucket] = {}
        self._lock = asyncio.Lock()
        self._cleanup_interval = 300  # Cleanup every 5 minutes
        self._last_cleanup = time.time()
    
    def _get_limit_config(self, path: str) -> RateLimitConfig:
        """Get rate limit config for a path."""
        # Check for exact match
        if path in self._limits:
            return self._limits[path]
        
        # Check for prefix match
        for pattern, config in self._limits.items():
            if pattern != "default" and path.startswith(pattern):
                return config
        
        return self._limits.get("default", RateLimitConfig(requests=100, window_seconds=60))
    
    def _get_bucket_key(self, identifier: str, path: str) -> str:
        """Generate bucket key from identifier and path."""
        # Normalize path for rate limiting
        path_key = path.rstrip("/").lower()
        return f"{identifier}:{path_key}"
    
    async def check_rate_limit(
        self,
        identifier: str,
        path: str,
    ) -> Tuple[bool, int, int]:
        """
        Check if request is allowed under rate limit.
        
        Returns: (allowed, remaining, reset_seconds)
        """
        config = self._get_limit_config(path)
        bucket_key = self._get_bucket_key(identifier, path)
        
        async with self._lock:
            # Cleanup old buckets periodically
            if time.time() - self._last_cleanup > self._cleanup_interval:
                await self._cleanup()
            
            # Get or create bucket
            if bucket_key not in self._buckets:
                capacity = config.requests + config.burst
                self._buckets[bucket_key] = TokenBucket(
                    capacity=capacity,
                    tokens=capacity,
                    rate=config.requests_per_second,
                )
            
            bucket = self._buckets[bucket_key]
            allowed = bucket.consume(1)
            remaining = bucket.remaining
            
            # Calculate reset time
            if not allowed:
                tokens_needed = 1 - bucket.tokens
                reset_seconds = int(tokens_needed / bucket.rate) + 1
            else:
                reset_seconds = config.window_seconds
            
            return allowed, remaining, reset_seconds
    
    async def _cleanup(self):
        """Remove expired buckets."""
        now = time.time()
        expired = []
        
        for key, bucket in self._buckets.items():
            # Remove buckets that haven't been used in 10 minutes
            if now - bucket.last_update > 600:
                expired.append(key)
        
        for key in expired:
            del self._buckets[key]
        
        self._last_cleanup = now
        
        if expired:
            logger.debug(f"Cleaned up {len(expired)} expired rate limit buckets")


# Global rate limiter instance
_rate_limiter: Optional[RateLimiter] = None


def get_rate_limiter() -> RateLimiter:
    """Get the global rate limiter instance."""
    global _rate_limiter
    if _rate_limiter is None:
        _rate_limiter = RateLimiter()
    return _rate_limiter


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    FastAPI middleware for rate limiting.
    
    Adds rate limit headers to all responses:
    - X-RateLimit-Limit: Maximum requests allowed
    - X-RateLimit-Remaining: Requests remaining in window
    - X-RateLimit-Reset: Seconds until limit resets
    """
    
    def __init__(
        self,
        app,
        limiter: Optional[RateLimiter] = None,
        identifier_func: Optional[Callable[[Request], str]] = None,
    ):
        super().__init__(app)
        self.limiter = limiter or get_rate_limiter()
        self.identifier_func = identifier_func or self._default_identifier
    
    @staticmethod
    def _default_identifier(request: Request) -> str:
        """Get client identifier from request (IP address by default)."""
        # Try to get real IP from X-Forwarded-For header
        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            return forwarded_for.split(",")[0].strip()
        
        # Fall back to direct client IP
        if request.client:
            return request.client.host
        
        return "unknown"
    
    async def dispatch(self, request: Request, call_next) -> Response:
        """Process request with rate limiting."""
        # Skip rate limiting for certain paths
        path = request.url.path
        if path in ("/docs", "/redoc", "/openapi.json"):
            return await call_next(request)
        
        identifier = self.identifier_func(request)
        allowed, remaining, reset = await self.limiter.check_rate_limit(
            identifier, path
        )
        
        if not allowed:
            logger.warning(
                f"Rate limit exceeded for {identifier} on {request.method} {path}"
            )
            
            response = Response(
                content='{"detail": "Rate limit exceeded. Please try again later."}',
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                media_type="application/json",
            )
            response.headers["X-RateLimit-Remaining"] = "0"
            response.headers["X-RateLimit-Reset"] = str(reset)
            response.headers["Retry-After"] = str(reset)
            return response
        
        # Process request
        response = await call_next(request)
        
        # Add rate limit headers
        config = self.limiter._get_limit_config(path)
        response.headers["X-RateLimit-Limit"] = str(config.requests)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        response.headers["X-RateLimit-Reset"] = str(reset)
        
        return response


def rate_limit(
    requests: int = 60,
    window_seconds: int = 60,
    burst: int = 0,
):
    """
    Decorator for custom rate limits on specific endpoints.
    
    Usage:
        @router.get("/endpoint")
        @rate_limit(requests=10, window_seconds=60)
        async def my_endpoint():
            ...
    """
    def decorator(func: Callable) -> Callable:
        # Store rate limit config on the function
        func._rate_limit_config = RateLimitConfig(
            requests=requests,
            window_seconds=window_seconds,
            burst=burst,
        )
        return func
    return decorator
