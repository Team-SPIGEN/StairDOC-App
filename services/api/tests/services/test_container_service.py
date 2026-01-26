"""
Unit tests for container service.

Tests:
- Lock/unlock commands
- Status queries
- Circuit breaker behavior
- Retry logic
"""

import pytest
from datetime import datetime, timedelta
from unittest.mock import AsyncMock, patch, MagicMock

from app.services.container_service import (
    ContainerService,
    ContainerState,
    ContainerStatus,
    HardwareConnectionError,
)


class TestContainerServiceInit:
    """Tests for ContainerService initialization."""
    
    def test_default_config(self):
        """Test default configuration values."""
        service = ContainerService()
        assert service.pi_host == "localhost"
        assert service.pi_port == 5000
        assert service.timeout == 5.0
        assert service.max_retries == 3
    
    def test_custom_config(self):
        """Test custom configuration."""
        service = ContainerService(
            pi_host="192.168.1.100",
            pi_port=8080,
            timeout=10.0,
            max_retries=5,
        )
        assert service.pi_host == "192.168.1.100"
        assert service.pi_port == 8080
        assert service.timeout == 10.0
        assert service.max_retries == 5
    
    def test_base_url(self):
        """Test base URL construction."""
        service = ContainerService(pi_host="192.168.1.50", pi_port=6000)
        assert service._base_url == "http://192.168.1.50:6000"


class TestContainerState:
    """Tests for ContainerState enum."""
    
    def test_locked_state(self):
        """Test locked state."""
        assert ContainerState.LOCKED == "locked"
    
    def test_unlocked_state(self):
        """Test unlocked state."""
        assert ContainerState.UNLOCKED == "unlocked"
    
    def test_unknown_state(self):
        """Test unknown state."""
        assert ContainerState.UNKNOWN == "unknown"


class TestContainerStatus:
    """Tests for ContainerStatus dataclass."""
    
    def test_locked_status(self):
        """Test creating locked status."""
        status = ContainerStatus(state=ContainerState.LOCKED)
        assert status.state == ContainerState.LOCKED
        assert status.battery_ok is True
        assert status.error is None
    
    def test_status_with_error(self):
        """Test status with error."""
        status = ContainerStatus(
            state=ContainerState.UNKNOWN,
            error="Hardware timeout",
        )
        assert status.state == ContainerState.UNKNOWN
        assert status.error == "Hardware timeout"
    
    def test_status_with_timestamp(self):
        """Test status with timestamp."""
        now = datetime.utcnow()
        status = ContainerStatus(
            state=ContainerState.UNLOCKED,
            last_changed=now,
        )
        assert status.last_changed == now


class TestUnlockCommand:
    """Tests for unlock command."""
    
    @pytest.mark.asyncio
    async def test_unlock_success(self):
        """Test successful unlock command."""
        service = ContainerService()
        
        result = await service.send_unlock_command()
        
        assert result.state == ContainerState.UNLOCKED
        assert result.error is None
    
    @pytest.mark.asyncio
    async def test_unlock_updates_state(self):
        """Test that unlock updates mock state."""
        service = ContainerService()
        service._mock_state = ContainerState.LOCKED
        
        await service.send_unlock_command()
        
        assert service._mock_state == ContainerState.UNLOCKED


class TestLockCommand:
    """Tests for lock command."""
    
    @pytest.mark.asyncio
    async def test_lock_success(self):
        """Test successful lock command."""
        service = ContainerService()
        service._mock_state = ContainerState.UNLOCKED
        
        result = await service.send_lock_command()
        
        assert result.state == ContainerState.LOCKED
        assert result.error is None
    
    @pytest.mark.asyncio
    async def test_lock_updates_state(self):
        """Test that lock updates mock state."""
        service = ContainerService()
        service._mock_state = ContainerState.UNLOCKED
        
        await service.send_lock_command()
        
        assert service._mock_state == ContainerState.LOCKED


class TestGetStatus:
    """Tests for get_status command."""
    
    @pytest.mark.asyncio
    async def test_get_locked_status(self):
        """Test getting locked status."""
        service = ContainerService()
        service._mock_state = ContainerState.LOCKED
        
        result = await service.get_status()
        
        assert result.state == ContainerState.LOCKED
    
    @pytest.mark.asyncio
    async def test_get_unlocked_status(self):
        """Test getting unlocked status."""
        service = ContainerService()
        service._mock_state = ContainerState.UNLOCKED
        
        result = await service.get_status()
        
        assert result.state == ContainerState.UNLOCKED


class TestCircuitBreaker:
    """Tests for circuit breaker pattern."""
    
    def test_initial_circuit_closed(self):
        """Test circuit starts closed."""
        service = ContainerService()
        assert service._circuit_open is False
        assert service._consecutive_failures == 0
    
    def test_circuit_breaker_state(self):
        """Test circuit breaker state tracking."""
        service = ContainerService()
        
        # Simulate failures
        service._consecutive_failures = 3
        
        # Circuit should still be closed (needs to be triggered)
        assert service._circuit_open is False


class TestCommandSequence:
    """Tests for command sequences."""
    
    @pytest.mark.asyncio
    async def test_lock_unlock_cycle(self):
        """Test lock-unlock-lock cycle."""
        service = ContainerService()
        
        # Start locked
        service._mock_state = ContainerState.LOCKED
        status = await service.get_status()
        assert status.state == ContainerState.LOCKED
        
        # Unlock
        await service.send_unlock_command()
        status = await service.get_status()
        assert status.state == ContainerState.UNLOCKED
        
        # Lock again
        await service.send_lock_command()
        status = await service.get_status()
        assert status.state == ContainerState.LOCKED
    
    @pytest.mark.asyncio
    async def test_multiple_unlocks(self):
        """Test multiple unlock commands."""
        service = ContainerService()
        
        # First unlock
        result1 = await service.send_unlock_command()
        assert result1.state == ContainerState.UNLOCKED
        
        # Second unlock (should still work)
        result2 = await service.send_unlock_command()
        assert result2.state == ContainerState.UNLOCKED


class TestHardwareConnectionError:
    """Tests for hardware connection error."""
    
    def test_exception_creation(self):
        """Test creating hardware connection error."""
        error = HardwareConnectionError("Connection refused")
        assert str(error) == "Connection refused"
    
    def test_exception_inheritance(self):
        """Test error is a proper exception."""
        error = HardwareConnectionError()
        assert isinstance(error, Exception)


class TestRetryLogic:
    """Tests for retry logic."""
    
    def test_retry_config(self):
        """Test retry configuration."""
        service = ContainerService(max_retries=5)
        assert service.max_retries == 5
    
    def test_timeout_config(self):
        """Test timeout configuration."""
        service = ContainerService(timeout=10.0)
        assert service.timeout == 10.0
