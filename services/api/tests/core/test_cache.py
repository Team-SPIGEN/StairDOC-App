"""
Unit tests for cache service.

Tests:
- Local cache operations
- TTL handling
- Pattern deletion
- Cache decorators
"""

import pytest
import time
from unittest.mock import MagicMock, AsyncMock, patch

from app.core.cache import (
    CacheService, 
    DEFAULT_TTL, 
    ROBOT_STATUS_TTL, 
    USER_SESSION_TTL,
    DELIVERY_QUEUE_TTL,
    ACCESS_LOG_TTL,
    CAMERA_STREAM_TTL,
)


class TestCacheServiceInit:
    """Tests for CacheService initialization."""
    
    def test_create_cache_service(self):
        """Test creating cache service without Redis."""
        cache = CacheService()
        assert cache is not None
        assert not cache.is_connected
    
    def test_create_cache_service_with_url(self):
        """Test creating cache service with Redis URL."""
        cache = CacheService(redis_url="redis://localhost:6379")
        assert cache._redis_url == "redis://localhost:6379"
        assert not cache.is_connected  # Not connected until connect() is called


class TestLocalCacheOperations:
    """Tests for local cache (without Redis)."""
    
    @pytest.mark.asyncio
    async def test_set_and_get(self):
        """Test setting and getting values."""
        cache = CacheService()
        
        result = await cache.set("test_key", {"foo": "bar"}, ttl=60)
        assert result is True
        
        value = await cache.get("test_key")
        assert value == {"foo": "bar"}
    
    @pytest.mark.asyncio
    async def test_get_nonexistent(self):
        """Test getting non-existent key."""
        cache = CacheService()
        value = await cache.get("nonexistent_key")
        assert value is None
    
    @pytest.mark.asyncio
    async def test_delete(self):
        """Test deleting a key."""
        cache = CacheService()
        
        await cache.set("delete_me", "value", ttl=60)
        assert await cache.get("delete_me") is not None
        
        result = await cache.delete("delete_me")
        assert result is True
        assert await cache.get("delete_me") is None
    
    @pytest.mark.asyncio
    async def test_delete_nonexistent(self):
        """Test deleting non-existent key."""
        cache = CacheService()
        result = await cache.delete("nonexistent_key")
        assert result is True  # Should succeed silently
    
    @pytest.mark.asyncio
    async def test_exists(self):
        """Test checking key existence."""
        cache = CacheService()
        
        assert await cache.exists("test_exists") is False
        
        await cache.set("test_exists", "value", ttl=60)
        assert await cache.exists("test_exists") is True
    
    @pytest.mark.asyncio
    async def test_delete_pattern(self):
        """Test pattern-based deletion."""
        cache = CacheService()
        
        # Set multiple keys
        await cache.set("robot:status:001", {"status": "idle"}, ttl=60)
        await cache.set("robot:status:002", {"status": "moving"}, ttl=60)
        await cache.set("user:session:abc", {"user": "test"}, ttl=60)
        
        # Delete robot status keys
        deleted = await cache.delete_pattern("robot:status:*")
        assert deleted == 2
        
        # Verify robot keys are gone
        assert await cache.get("robot:status:001") is None
        assert await cache.get("robot:status:002") is None
        
        # User key should still exist
        assert await cache.get("user:session:abc") is not None


class TestCacheTTL:
    """Tests for TTL-based expiration."""
    
    @pytest.mark.asyncio
    async def test_ttl_expiration(self):
        """Test that cached values expire after TTL."""
        cache = CacheService()
        
        # Set with 1 second TTL
        await cache.set("short_lived", "value", ttl=1)
        
        # Should exist immediately
        assert await cache.get("short_lived") == "value"
        
        # Wait for expiration
        time.sleep(1.5)
        
        # Should be expired
        assert await cache.get("short_lived") is None
    
    def test_default_ttl_values(self):
        """Test default TTL constants."""
        assert DEFAULT_TTL == 60
        assert ROBOT_STATUS_TTL == 5
        assert USER_SESSION_TTL == 900
        assert DELIVERY_QUEUE_TTL == 30
        assert ACCESS_LOG_TTL == 60
        assert CAMERA_STREAM_TTL == 10


class TestCacheConnection:
    """Tests for Redis connection handling."""
    
    @pytest.mark.asyncio
    async def test_connect_without_url(self):
        """Test connect with no Redis URL."""
        cache = CacheService()
        result = await cache.connect()
        assert result is False
        assert not cache.is_connected
    
    @pytest.mark.asyncio
    async def test_disconnect(self):
        """Test disconnecting."""
        cache = CacheService()
        await cache.disconnect()  # Should not raise
        assert not cache.is_connected


class TestCacheDataTypes:
    """Tests for different data types."""
    
    @pytest.mark.asyncio
    async def test_cache_string(self):
        """Test caching string values."""
        cache = CacheService()
        await cache.set("string_key", "hello world", ttl=60)
        assert await cache.get("string_key") == "hello world"
    
    @pytest.mark.asyncio
    async def test_cache_dict(self):
        """Test caching dict values."""
        cache = CacheService()
        data = {"name": "robot", "status": "idle", "battery": 100}
        await cache.set("dict_key", data, ttl=60)
        assert await cache.get("dict_key") == data
    
    @pytest.mark.asyncio
    async def test_cache_list(self):
        """Test caching list values."""
        cache = CacheService()
        data = [1, 2, 3, "four", {"five": 5}]
        await cache.set("list_key", data, ttl=60)
        assert await cache.get("list_key") == data
    
    @pytest.mark.asyncio
    async def test_cache_number(self):
        """Test caching numeric values."""
        cache = CacheService()
        await cache.set("int_key", 42, ttl=60)
        await cache.set("float_key", 3.14, ttl=60)
        assert await cache.get("int_key") == 42
        assert await cache.get("float_key") == 3.14
    
    @pytest.mark.asyncio
    async def test_cache_bool(self):
        """Test caching boolean values."""
        cache = CacheService()
        await cache.set("true_key", True, ttl=60)
        await cache.set("false_key", False, ttl=60)
        assert await cache.get("true_key") is True
        assert await cache.get("false_key") is False
    
    @pytest.mark.asyncio
    async def test_cache_none(self):
        """Test caching None value."""
        cache = CacheService()
        await cache.set("none_key", None, ttl=60)
        result = await cache.get("none_key")
        assert result is None


class TestCacheKeyNaming:
    """Tests for cache key patterns."""
    
    @pytest.mark.asyncio
    async def test_robot_status_key(self):
        """Test robot status key pattern."""
        cache = CacheService()
        key = f"robot:status:robot-001"
        await cache.set(key, {"battery": 85}, ttl=ROBOT_STATUS_TTL)
        assert await cache.get(key) == {"battery": 85}
    
    @pytest.mark.asyncio
    async def test_user_session_key(self):
        """Test user session key pattern."""
        cache = CacheService()
        key = f"session:user123"
        await cache.set(key, {"role": "admin"}, ttl=USER_SESSION_TTL)
        assert await cache.get(key) == {"role": "admin"}
    
    @pytest.mark.asyncio
    async def test_delivery_queue_key(self):
        """Test delivery queue key pattern."""
        cache = CacheService()
        key = f"delivery:queue"
        await cache.set(key, [{"id": "job1"}, {"id": "job2"}], ttl=DELIVERY_QUEUE_TTL)
        result = await cache.get(key)
        assert len(result) == 2


class TestCacheCleanup:
    """Tests for cache cleanup operations."""
    
    @pytest.mark.asyncio
    async def test_clear_all_robot_status(self):
        """Test clearing all robot status entries."""
        cache = CacheService()
        
        # Add multiple robot statuses
        for i in range(5):
            await cache.set(f"robot:status:{i}", {"id": i}, ttl=60)
        
        # Clear all
        deleted = await cache.delete_pattern("robot:status:*")
        assert deleted == 5
    
    @pytest.mark.asyncio
    async def test_clear_specific_pattern(self):
        """Test clearing with specific pattern."""
        cache = CacheService()
        
        await cache.set("user:session:abc", {}, ttl=60)
        await cache.set("user:profile:abc", {}, ttl=60)
        await cache.set("user:session:xyz", {}, ttl=60)
        
        # Clear only sessions
        deleted = await cache.delete_pattern("user:session:*")
        assert deleted == 2
        
        # Profile should remain
        assert await cache.exists("user:profile:abc") is True


class TestCacheOverwrite:
    """Tests for overwriting cached values."""
    
    @pytest.mark.asyncio
    async def test_overwrite_value(self):
        """Test overwriting an existing value."""
        cache = CacheService()
        
        await cache.set("key", "original", ttl=60)
        assert await cache.get("key") == "original"
        
        await cache.set("key", "updated", ttl=60)
        assert await cache.get("key") == "updated"
    
    @pytest.mark.asyncio
    async def test_overwrite_with_different_type(self):
        """Test overwriting with different type."""
        cache = CacheService()
        
        await cache.set("type_key", "string", ttl=60)
        await cache.set("type_key", 123, ttl=60)
        assert await cache.get("type_key") == 123
        
        await cache.set("type_key", {"dict": True}, ttl=60)
        assert await cache.get("type_key") == {"dict": True}
