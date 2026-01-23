"""
Container access service for communicating with robot hardware.

This service handles:
- Sending lock/unlock commands to the Raspberry Pi
- Querying container status
- Retry logic with exponential backoff
- Circuit breaker pattern for hardware failures

The actual hardware communication is currently stubbed and returns
mock responses. Replace the stub implementations when integrating
with the real Raspberry Pi HTTP/MQTT client.
"""

import asyncio
import logging
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Optional

import httpx

logger = logging.getLogger(__name__)


class ContainerState(str, Enum):
    """Current state of the container lock."""
    LOCKED = "locked"
    UNLOCKED = "unlocked"
    UNKNOWN = "unknown"


@dataclass
class ContainerStatus:
    """Current container status from hardware."""
    state: ContainerState
    last_changed: Optional[datetime] = None
    battery_ok: bool = True
    error: Optional[str] = None


class HardwareConnectionError(Exception):
    """Raised when hardware communication fails."""
    pass


class ContainerService:
    """
    Service for controlling the robot's document container.
    
    This service acts as a bridge between the FastAPI backend and
    the Raspberry Pi hardware. It implements retry logic and
    graceful degradation when hardware is unavailable.
    
    Configuration:
        ROBOT_PI_HOST: Raspberry Pi hostname/IP (default: localhost)
        ROBOT_PI_PORT: Raspberry Pi HTTP port (default: 5000)
        HARDWARE_TIMEOUT: Request timeout in seconds (default: 5.0)
        MAX_RETRIES: Number of retry attempts (default: 3)
    """
    
    def __init__(
        self,
        pi_host: str = "localhost",
        pi_port: int = 5000,
        timeout: float = 5.0,
        max_retries: int = 3,
    ):
        self.pi_host = pi_host
        self.pi_port = pi_port
        self.timeout = timeout
        self.max_retries = max_retries
        self._base_url = f"http://{pi_host}:{pi_port}"
        
        # Circuit breaker state
        self._consecutive_failures = 0
        self._circuit_open = False
        self._circuit_open_until: Optional[datetime] = None
        
        # Mock state for development (remove when hardware ready)
        self._mock_state = ContainerState.LOCKED
        self._mock_last_changed = datetime.utcnow()
    
    async def send_unlock_command(self) -> ContainerStatus:
        """
        Send unlock command to the container.
        
        Returns:
            ContainerStatus with current state after command
            
        Raises:
            HardwareConnectionError: If hardware communication fails
        """
        return await self._send_command("unlock")
    
    async def send_lock_command(self) -> ContainerStatus:
        """
        Send lock command to the container.
        
        Returns:
            ContainerStatus with current state after command
            
        Raises:
            HardwareConnectionError: If hardware communication fails
        """
        return await self._send_command("lock")
    
    async def get_status(self) -> ContainerStatus:
        """
        Query current container status from hardware.
        
        Returns:
            ContainerStatus with current state
            
        Raises:
            HardwareConnectionError: If hardware communication fails
        """
        # Check circuit breaker
        if self._is_circuit_open():
            logger.warning("Circuit breaker open, returning cached status")
            return ContainerStatus(
                state=self._mock_state,
                last_changed=self._mock_last_changed,
                error="Hardware temporarily unavailable"
            )
        
        # TODO: Replace with actual hardware call
        # try:
        #     async with httpx.AsyncClient(timeout=self.timeout) as client:
        #         response = await client.get(f"{self._base_url}/container/status")
        #         response.raise_for_status()
        #         data = response.json()
        #         self._reset_circuit_breaker()
        #         return ContainerStatus(
        #             state=ContainerState(data["state"]),
        #             last_changed=datetime.fromisoformat(data["last_changed"]),
        #             battery_ok=data.get("battery_ok", True),
        #         )
        # except Exception as e:
        #     self._record_failure()
        #     raise HardwareConnectionError(f"Failed to get status: {e}")
        
        # MOCK IMPLEMENTATION - Remove when hardware ready
        logger.info("[MOCK] Getting container status")
        return ContainerStatus(
            state=self._mock_state,
            last_changed=self._mock_last_changed,
            battery_ok=True,
        )
    
    async def _send_command(self, action: str) -> ContainerStatus:
        """
        Internal method to send lock/unlock command with retry logic.
        
        Args:
            action: 'lock' or 'unlock'
            
        Returns:
            ContainerStatus after command execution
            
        Raises:
            HardwareConnectionError: If all retries fail
        """
        # Check circuit breaker
        if self._is_circuit_open():
            raise HardwareConnectionError(
                "Hardware temporarily unavailable (circuit breaker open)"
            )
        
        last_error: Optional[Exception] = None
        
        for attempt in range(self.max_retries):
            try:
                result = await self._execute_command(action)
                self._reset_circuit_breaker()
                return result
            except Exception as e:
                last_error = e
                logger.warning(
                    f"Command '{action}' failed (attempt {attempt + 1}/{self.max_retries}): {e}"
                )
                if attempt < self.max_retries - 1:
                    # Exponential backoff: 1s, 2s, 4s...
                    await asyncio.sleep(2 ** attempt)
        
        self._record_failure()
        raise HardwareConnectionError(
            f"Failed to {action} after {self.max_retries} attempts: {last_error}"
        )
    
    async def _execute_command(self, action: str) -> ContainerStatus:
        """
        Execute a single command attempt against hardware.
        
        TODO: Replace mock implementation with actual HTTP call to Raspberry Pi.
        
        Expected Raspberry Pi API:
            POST /container/lock   -> {"state": "locked", "timestamp": "..."}
            POST /container/unlock -> {"state": "unlocked", "timestamp": "..."}
        """
        # TODO: Replace with actual hardware call
        # async with httpx.AsyncClient(timeout=self.timeout) as client:
        #     response = await client.post(f"{self._base_url}/container/{action}")
        #     response.raise_for_status()
        #     data = response.json()
        #     return ContainerStatus(
        #         state=ContainerState(data["state"]),
        #         last_changed=datetime.fromisoformat(data["timestamp"]),
        #     )
        
        # MOCK IMPLEMENTATION - Remove when hardware ready
        logger.info(f"[MOCK] Executing container {action} command")
        await asyncio.sleep(0.1)  # Simulate network latency
        
        now = datetime.utcnow()
        if action == "lock":
            self._mock_state = ContainerState.LOCKED
        else:
            self._mock_state = ContainerState.UNLOCKED
        self._mock_last_changed = now
        
        return ContainerStatus(
            state=self._mock_state,
            last_changed=now,
            battery_ok=True,
        )
    
    def _is_circuit_open(self) -> bool:
        """Check if circuit breaker is currently open."""
        if not self._circuit_open:
            return False
        
        if self._circuit_open_until and datetime.utcnow() > self._circuit_open_until:
            # Half-open: allow one request through
            self._circuit_open = False
            return False
        
        return True
    
    def _record_failure(self) -> None:
        """Record a failure and potentially open circuit breaker."""
        self._consecutive_failures += 1
        
        if self._consecutive_failures >= 5:
            self._circuit_open = True
            # Open circuit for 30 seconds
            from datetime import timedelta
            self._circuit_open_until = datetime.utcnow() + timedelta(seconds=30)
            logger.error("Circuit breaker opened after 5 consecutive failures")
    
    def _reset_circuit_breaker(self) -> None:
        """Reset circuit breaker after successful request."""
        self._consecutive_failures = 0
        self._circuit_open = False
        self._circuit_open_until = None


# Singleton instance
container_service = ContainerService()
