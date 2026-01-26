"""
Unit tests for rate limiting module.

Tests:
- Token bucket algorithm
- Rate limiter per-IP tracking
- Rate limit configuration
"""

import asyncio
import time
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.core.rate_limit import (
    RateLimitConfig,
    RateLimiter,
    TokenBucket,
    DEFAULT_LIMITS,
)


class TestRateLimitConfig:
    """Tests for RateLimitConfig dataclass."""
    
    def test_config_creation(self):
        """Test configuration creation with values."""
        config = RateLimitConfig(requests=100, window_seconds=60)
        assert config.requests == 100
        assert config.window_seconds == 60
        assert config.burst == 0  # Default
    
    def test_custom_values(self):
        """Test custom configuration values."""
        config = RateLimitConfig(requests=50, window_seconds=30, burst=5)
        assert config.requests == 50
        assert config.window_seconds == 30
        assert config.burst == 5
    
    def test_requests_per_second(self):
        """Test requests per second calculation."""
        config = RateLimitConfig(requests=60, window_seconds=60)
        assert config.requests_per_second == 1.0
        
        config2 = RateLimitConfig(requests=120, window_seconds=60)
        assert config2.requests_per_second == 2.0
    
    def test_default_limits_exist(self):
        """Test that default limits are defined."""
        assert "/api/v1/auth/login" in DEFAULT_LIMITS
        assert "/api/v1/container/lock" in DEFAULT_LIMITS
        assert "/api/v1/voice/command" in DEFAULT_LIMITS
        assert "/api/v1/camera" in DEFAULT_LIMITS
        assert "default" in DEFAULT_LIMITS
    
    def test_auth_has_strict_limits(self):
        """Test that auth endpoints have stricter limits."""
        auth_config = DEFAULT_LIMITS["/api/v1/auth/login"]
        default_config = DEFAULT_LIMITS["default"]
        assert auth_config.requests < default_config.requests


class TestTokenBucket:
    """Tests for TokenBucket algorithm."""
    
    def test_bucket_creation(self):
        """Test bucket starts with configurable state."""
        bucket = TokenBucket(capacity=10, rate=1.0)
        assert bucket.capacity == 10
    
    def test_consume_with_refill(self):
        """Test consuming tokens triggers refill."""
        bucket = TokenBucket(capacity=10, tokens=10, rate=10.0)
        # Immediately after creation with tokens, should allow
        allowed = bucket.consume()
        assert allowed is True
    
    def test_reject_when_empty(self):
        """Test rejection when bucket is empty."""
        bucket = TokenBucket(capacity=2, tokens=0, rate=0.001)  # Very slow refill
        allowed = bucket.consume()
        # May or may not succeed depending on time elapsed
        # Let's test the bucket when truly empty
        bucket.tokens = 0
        bucket.last_update = time.time()  # Just now
        bucket.rate = 0.0001  # Very slow
        allowed = bucket.consume()
        assert allowed is False
    
    def test_refill_over_time(self):
        """Test that bucket refills over time."""
        bucket = TokenBucket(capacity=10, tokens=0, rate=100.0)  # Fast refill
        bucket.last_update = time.time() - 1.0  # 1 second ago
        
        # Should have refilled
        allowed = bucket.consume()
        assert allowed is True
    
    def test_capacity_limit(self):
        """Test that tokens don't exceed capacity."""
        bucket = TokenBucket(capacity=10, tokens=0, rate=1000.0)
        bucket.last_update = time.time() - 100  # Long time ago
        bucket.consume()  # Trigger refill
        assert bucket.tokens <= bucket.capacity
    
    def test_remaining_tokens(self):
        """Test remaining tokens property."""
        bucket = TokenBucket(capacity=10, tokens=5, rate=0)
        remaining = bucket.remaining
        assert remaining >= 0
        assert remaining <= bucket.capacity


class TestRateLimiter:
    """Tests for RateLimiter class."""
    
    def test_limiter_creation(self):
        """Test rate limiter can be created."""
        limiter = RateLimiter()
        assert limiter is not None
    
    @pytest.mark.asyncio
    async def test_new_client_tracked(self):
        """Test that new clients get tracked."""
        limiter = RateLimiter()
        # The check_rate_limit method should work
        allowed, remaining, reset = await limiter.check_rate_limit("192.168.1.1", "/api/v1/test")
        # Should be boolean
        assert isinstance(allowed, bool)
        assert allowed is True  # First request should be allowed
    
    @pytest.mark.asyncio
    async def test_different_ips_tracked_separately(self):
        """Test that different IPs are tracked separately."""
        limiter = RateLimiter()
        
        # Both should work independently
        allowed1, _, _ = await limiter.check_rate_limit("192.168.1.1", "/api/v1/test")
        allowed2, _, _ = await limiter.check_rate_limit("192.168.1.2", "/api/v1/test")
        # Both should be allowed initially
        assert allowed1 is True
        assert allowed2 is True
    
    @pytest.mark.asyncio
    async def test_rate_limit_can_be_exceeded(self):
        """Test that rate limit can be hit."""
        # Create limiter with strict config for testing
        strict_limits = {
            "/test/restrictive": RateLimitConfig(requests=2, window_seconds=60, burst=0),
            "default": RateLimitConfig(requests=100, window_seconds=60),
        }
        limiter = RateLimiter(limits=strict_limits)
        
        # Make many requests - eventually should hit limit
        results = []
        for _ in range(10):
            allowed, _, _ = await limiter.check_rate_limit("192.168.1.100", "/test/restrictive")
            results.append(allowed)
        
        # First 2 should be allowed, rest should be denied (or close to that)
        assert results[0] is True
        assert results[1] is True
        # Some should have failed
        assert False in results[2:]
    
    def test_get_limit_config_exact_match(self):
        """Test configuration lookup for exact path match."""
        limiter = RateLimiter()
        
        config = limiter._get_limit_config("/api/v1/auth/login")
        assert config.requests == 5  # Auth limit
    
    def test_get_limit_config_prefix_match(self):
        """Test configuration lookup for prefix match."""
        limiter = RateLimiter()
        
        # This should match /api/v1/camera prefix
        config = limiter._get_limit_config("/api/v1/camera/stream")
        assert config.requests == 120  # Camera limit
    
    def test_get_limit_config_default(self):
        """Test configuration lookup returns default for unknown paths."""
        limiter = RateLimiter()
        
        config = limiter._get_limit_config("/api/v1/unknown/endpoint")
        assert config.requests == 100  # Default limit


class TestRateLimitIntegration:
    """Integration tests for rate limiting."""
    
    @pytest.mark.asyncio
    async def test_default_config_allows_normal_traffic(self):
        """Test that default config allows reasonable traffic."""
        limiter = RateLimiter()
        
        # Normal traffic pattern should be allowed
        allowed = 0
        for _ in range(10):
            result, _, _ = await limiter.check_rate_limit("normal-client", "/api/v1/test")
            if result:
                allowed += 1
        
        # Most should be allowed
        assert allowed >= 5
    
    @pytest.mark.asyncio
    async def test_different_endpoints_tracked(self):
        """Test that different endpoints can have different limits."""
        limiter = RateLimiter()
        
        # Auth endpoint
        auth_result, _, _ = await limiter.check_rate_limit("192.168.1.1", "/api/v1/auth/login")
        
        # Regular endpoint - should have its own tracking
        regular_result, _, _ = await limiter.check_rate_limit("192.168.1.1", "/api/v1/robot/status")
        
        # Both should be allowed initially
        assert auth_result is True
        assert regular_result is True
    
    @pytest.mark.asyncio
    async def test_returns_remaining_and_reset(self):
        """Test that check_rate_limit returns remaining tokens and reset time."""
        limiter = RateLimiter()
        
        allowed, remaining, reset_seconds = await limiter.check_rate_limit("test-client", "/api/v1/test")
        
        assert allowed is True
        assert remaining >= 0
        assert reset_seconds > 0
