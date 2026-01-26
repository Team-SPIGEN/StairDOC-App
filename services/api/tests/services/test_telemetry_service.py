"""
Unit tests for TelemetryService.

Tests:
- Telemetry state management
- WebSocket connection handling
- Subscription filtering
- Mock telemetry generation
"""

import pytest
import asyncio
from datetime import datetime
from unittest.mock import MagicMock, AsyncMock, patch

from app.services.telemetry_service import TelemetryService
from app.schemas.telemetry import (
    TelemetryData,
    BatteryStatus,
    LocationData,
    MotionData,
    ContainerState,
    ConnectivityStatus,
    SensorData,
    SystemHealth,
    RobotState,
)


@pytest.fixture
def telemetry_service():
    """Create a fresh TelemetryService instance."""
    return TelemetryService()


@pytest.fixture
def sample_telemetry():
    """Create sample telemetry data."""
    return TelemetryData(
        robot_id="robot-001",
        timestamp=datetime.utcnow(),
        state=RobotState.idle,
        battery=BatteryStatus(
            percentage=85,
            is_charging=False,
            voltage=12.5,
            temperature=25.0,
            estimated_runtime_minutes=200,
        ),
        location=LocationData(
            floor=1,
            zone="A",
            x=10.5,
            y=20.3,
            heading=45.0,
        ),
        motion=MotionData(
            linear_velocity=0.0,
            angular_velocity=0.0,
            is_moving=False,
            target_floor=None,
        ),
        container_state=ContainerState.locked,
        connectivity=ConnectivityStatus.online,
        sensors=SensorData(
            front_distance=100.0,
            rear_distance=100.0,
            left_distance=80.0,
            right_distance=80.0,
            cliff_detected=False,
            stair_detected=False,
            ambient_temperature=22.0,
            humidity=45.0,
        ),
        system=SystemHealth(
            cpu_usage=25.0,
            memory_usage=40.0,
            disk_usage=30.0,
            wifi_signal=-50,
            uptime_seconds=3600,
        ),
    )


class TestTelemetryServiceInit:
    """Tests for TelemetryService initialization."""
    
    def test_init_default_values(self, telemetry_service):
        """Test service initializes with empty state."""
        assert telemetry_service._telemetry == {}
        assert telemetry_service._connections == set()
        assert telemetry_service._subscriptions == {}
        assert telemetry_service._mock_mode is True
        assert telemetry_service._mock_task is None


class TestTelemetryStateManagement:
    """Tests for telemetry state management."""
    
    @pytest.mark.asyncio
    async def test_update_telemetry(self, telemetry_service, sample_telemetry):
        """Test updating telemetry state."""
        await telemetry_service.update_telemetry(sample_telemetry)
        
        assert "robot-001" in telemetry_service._telemetry
        assert telemetry_service._telemetry["robot-001"] == sample_telemetry
    
    def test_get_telemetry(self, telemetry_service, sample_telemetry):
        """Test getting telemetry for specific robot."""
        telemetry_service._telemetry["robot-001"] = sample_telemetry
        
        result = telemetry_service.get_telemetry("robot-001")
        
        assert result == sample_telemetry
    
    def test_get_telemetry_not_found(self, telemetry_service):
        """Test getting telemetry for non-existent robot."""
        result = telemetry_service.get_telemetry("unknown-robot")
        
        assert result is None
    
    def test_get_all_telemetry(self, telemetry_service, sample_telemetry):
        """Test getting all telemetry data."""
        telemetry_service._telemetry["robot-001"] = sample_telemetry
        
        result = telemetry_service.get_all_telemetry()
        
        assert len(result) == 1
        assert "robot-001" in result
    
    def test_get_all_telemetry_empty(self, telemetry_service):
        """Test getting all telemetry when empty."""
        result = telemetry_service.get_all_telemetry()
        
        assert result == {}
    
    @pytest.mark.asyncio
    async def test_update_multiple_robots(self, telemetry_service, sample_telemetry):
        """Test updating telemetry for multiple robots."""
        await telemetry_service.update_telemetry(sample_telemetry)
        
        # Create another robot's telemetry
        sample_telemetry.robot_id = "robot-002"
        await telemetry_service.update_telemetry(sample_telemetry)
        
        assert len(telemetry_service._telemetry) == 2


class TestWebSocketConnections:
    """Tests for WebSocket connection management."""
    
    @pytest.mark.asyncio
    async def test_connect(self, telemetry_service):
        """Test connecting a WebSocket."""
        mock_ws = AsyncMock()
        
        await telemetry_service.connect(mock_ws)
        
        assert mock_ws in telemetry_service._connections
        assert mock_ws in telemetry_service._subscriptions
    
    @pytest.mark.asyncio
    async def test_connect_with_subscription(self, telemetry_service):
        """Test connecting with subscription preferences."""
        mock_ws = AsyncMock()
        subscription = {"robot_id": "robot-001", "include_sensors": True}
        
        await telemetry_service.connect(mock_ws, subscription)
        
        assert telemetry_service._subscriptions[mock_ws] == subscription
    
    @pytest.mark.asyncio
    async def test_disconnect(self, telemetry_service):
        """Test disconnecting a WebSocket."""
        mock_ws = AsyncMock()
        telemetry_service._connections.add(mock_ws)
        telemetry_service._subscriptions[mock_ws] = {}
        
        await telemetry_service.disconnect(mock_ws)
        
        assert mock_ws not in telemetry_service._connections
        assert mock_ws not in telemetry_service._subscriptions
    
    @pytest.mark.asyncio
    async def test_disconnect_nonexistent(self, telemetry_service):
        """Test disconnecting non-existent WebSocket is safe."""
        mock_ws = AsyncMock()
        
        # Should not raise
        await telemetry_service.disconnect(mock_ws)
    
    def test_update_subscription(self, telemetry_service):
        """Test updating subscription preferences."""
        mock_ws = AsyncMock()
        telemetry_service._connections.add(mock_ws)
        telemetry_service._subscriptions[mock_ws] = {}
        
        new_sub = {"robot_id": "robot-002"}
        telemetry_service.update_subscription(mock_ws, new_sub)
        
        assert telemetry_service._subscriptions[mock_ws] == new_sub
    
    def test_update_subscription_not_connected(self, telemetry_service):
        """Test updating subscription for non-connected client."""
        mock_ws = AsyncMock()
        
        # Should not raise, just do nothing
        telemetry_service.update_subscription(mock_ws, {"robot_id": "test"})
        
        assert mock_ws not in telemetry_service._subscriptions


class TestSubscriptionFiltering:
    """Tests for subscription-based filtering."""
    
    def test_should_send_no_filter(self, telemetry_service, sample_telemetry):
        """Test should_send with no filter (send all)."""
        mock_ws = AsyncMock()
        telemetry_service._subscriptions[mock_ws] = {}
        
        result = telemetry_service._should_send(mock_ws, sample_telemetry)
        
        assert result is True
    
    def test_should_send_matching_robot(self, telemetry_service, sample_telemetry):
        """Test should_send with matching robot filter."""
        mock_ws = AsyncMock()
        telemetry_service._subscriptions[mock_ws] = {"robot_id": "robot-001"}
        
        result = telemetry_service._should_send(mock_ws, sample_telemetry)
        
        assert result is True
    
    def test_should_send_non_matching_robot(self, telemetry_service, sample_telemetry):
        """Test should_send with non-matching robot filter."""
        mock_ws = AsyncMock()
        telemetry_service._subscriptions[mock_ws] = {"robot_id": "robot-999"}
        
        result = telemetry_service._should_send(mock_ws, sample_telemetry)
        
        assert result is False
    
    def test_should_send_no_subscription(self, telemetry_service, sample_telemetry):
        """Test should_send when no subscription record exists."""
        mock_ws = AsyncMock()
        
        result = telemetry_service._should_send(mock_ws, sample_telemetry)
        
        # No subscription means no filter, send all
        assert result is True


class TestBroadcasting:
    """Tests for telemetry broadcasting."""
    
    @pytest.mark.asyncio
    async def test_broadcast_to_subscribers(self, telemetry_service, sample_telemetry):
        """Test broadcasting to subscribed clients."""
        mock_ws1 = AsyncMock()
        mock_ws2 = AsyncMock()
        
        telemetry_service._connections = {mock_ws1, mock_ws2}
        telemetry_service._subscriptions = {mock_ws1: {}, mock_ws2: {}}
        
        await telemetry_service._broadcast(sample_telemetry)
        
        # Both should receive
        mock_ws1.send_json.assert_called_once()
        mock_ws2.send_json.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_broadcast_filters_by_robot(self, telemetry_service, sample_telemetry):
        """Test broadcast respects robot filter."""
        mock_ws1 = AsyncMock()
        mock_ws2 = AsyncMock()
        
        telemetry_service._connections = {mock_ws1, mock_ws2}
        telemetry_service._subscriptions = {
            mock_ws1: {"robot_id": "robot-001"},  # Should receive
            mock_ws2: {"robot_id": "robot-999"},  # Should not receive
        }
        
        await telemetry_service._broadcast(sample_telemetry)
        
        mock_ws1.send_json.assert_called_once()
        mock_ws2.send_json.assert_not_called()
    
    @pytest.mark.asyncio
    async def test_broadcast_removes_disconnected(self, telemetry_service, sample_telemetry):
        """Test broadcast removes failed connections."""
        mock_ws = AsyncMock()
        mock_ws.send_json.side_effect = Exception("Connection closed")
        
        telemetry_service._connections = {mock_ws}
        telemetry_service._subscriptions = {mock_ws: {}}
        
        await telemetry_service._broadcast(sample_telemetry)
        
        # Should be removed after failure
        assert mock_ws not in telemetry_service._connections
    
    @pytest.mark.asyncio
    async def test_broadcast_no_connections(self, telemetry_service, sample_telemetry):
        """Test broadcast with no connections."""
        # Should not raise
        await telemetry_service._broadcast(sample_telemetry)
    
    @pytest.mark.asyncio
    async def test_broadcast_excludes_sensors(self, telemetry_service, sample_telemetry):
        """Test broadcast excludes sensors when not subscribed."""
        mock_ws = AsyncMock()
        
        telemetry_service._connections = {mock_ws}
        telemetry_service._subscriptions = {
            mock_ws: {"include_sensors": False}
        }
        
        await telemetry_service._broadcast(sample_telemetry)
        
        # Check the data sent
        call_args = mock_ws.send_json.call_args[0][0]
        assert "sensors" not in call_args
    
    @pytest.mark.asyncio
    async def test_broadcast_excludes_system(self, telemetry_service, sample_telemetry):
        """Test broadcast excludes system when not subscribed."""
        mock_ws = AsyncMock()
        
        telemetry_service._connections = {mock_ws}
        telemetry_service._subscriptions = {
            mock_ws: {"include_system": False}
        }
        
        await telemetry_service._broadcast(sample_telemetry)
        
        call_args = mock_ws.send_json.call_args[0][0]
        assert "system" not in call_args
    
    @pytest.mark.asyncio
    async def test_broadcast_includes_all_when_subscribed(self, telemetry_service, sample_telemetry):
        """Test broadcast includes all data when subscribed."""
        mock_ws = AsyncMock()
        
        telemetry_service._connections = {mock_ws}
        telemetry_service._subscriptions = {
            mock_ws: {"include_sensors": True, "include_system": True}
        }
        
        await telemetry_service._broadcast(sample_telemetry)
        
        call_args = mock_ws.send_json.call_args[0][0]
        assert "sensors" in call_args
        assert "system" in call_args


class TestMockTelemetry:
    """Tests for mock telemetry generation."""
    
    @pytest.mark.asyncio
    async def test_start_mock_telemetry(self, telemetry_service):
        """Test starting mock telemetry generation."""
        await telemetry_service.start_mock_telemetry("robot-001")
        
        assert telemetry_service._mock_task is not None
        assert telemetry_service._mock_mode is True
        
        # Clean up
        await telemetry_service.stop_mock_telemetry()
    
    @pytest.mark.asyncio
    async def test_start_mock_telemetry_already_running(self, telemetry_service):
        """Test starting mock when already running."""
        await telemetry_service.start_mock_telemetry("robot-001")
        task1 = telemetry_service._mock_task
        
        # Start again - should not create new task
        await telemetry_service.start_mock_telemetry("robot-001")
        
        assert telemetry_service._mock_task is task1
        
        # Clean up
        await telemetry_service.stop_mock_telemetry()
    
    @pytest.mark.asyncio
    async def test_stop_mock_telemetry(self, telemetry_service):
        """Test stopping mock telemetry generation."""
        await telemetry_service.start_mock_telemetry("robot-001")
        await telemetry_service.stop_mock_telemetry()
        
        assert telemetry_service._mock_task is None
    
    @pytest.mark.asyncio
    async def test_stop_mock_telemetry_not_running(self, telemetry_service):
        """Test stopping mock when not running."""
        # Should not raise
        await telemetry_service.stop_mock_telemetry()
        
        assert telemetry_service._mock_task is None


class TestConnectSendsCurrentState:
    """Tests for sending current state on connect."""
    
    @pytest.mark.asyncio
    async def test_connect_sends_current_telemetry(self, telemetry_service, sample_telemetry):
        """Test connecting sends current telemetry state."""
        telemetry_service._telemetry["robot-001"] = sample_telemetry
        
        mock_ws = AsyncMock()
        await telemetry_service.connect(mock_ws)
        
        # Should have sent current state
        mock_ws.send_json.assert_called()
    
    @pytest.mark.asyncio
    async def test_connect_respects_filter(self, telemetry_service, sample_telemetry):
        """Test connect respects robot filter when sending state."""
        telemetry_service._telemetry["robot-001"] = sample_telemetry
        
        mock_ws = AsyncMock()
        # Subscribe to different robot
        await telemetry_service.connect(mock_ws, {"robot_id": "robot-999"})
        
        # Should not have sent (wrong robot)
        mock_ws.send_json.assert_not_called()
    
    @pytest.mark.asyncio
    async def test_connect_handles_send_error(self, telemetry_service, sample_telemetry):
        """Test connect handles send errors gracefully."""
        telemetry_service._telemetry["robot-001"] = sample_telemetry
        
        mock_ws = AsyncMock()
        mock_ws.send_json.side_effect = Exception("Send failed")
        
        # Should not raise
        await telemetry_service.connect(mock_ws)
        
        # Still added to connections
        assert mock_ws in telemetry_service._connections
