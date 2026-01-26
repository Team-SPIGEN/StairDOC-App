"""
Unit tests for robot schemas.

Tests:
- Robot endpoint validation
- Status schema validation
- Command validation
"""

import pytest
from datetime import datetime
from pydantic import ValidationError

from app.schemas.robot import (
    RobotEndpoint,
    RobotStatus,
    CommandRequest,
)


class TestRobotEndpoint:
    """Tests for RobotEndpoint schema."""
    
    def test_valid_endpoint(self):
        """Test valid robot endpoint."""
        endpoint = RobotEndpoint(
            id="robot-001",
            name="StairBot Alpha",
            host="192.168.1.100",
            port=8000,
        )
        assert endpoint.id == "robot-001"
        assert endpoint.name == "StairBot Alpha"
        assert endpoint.host == "192.168.1.100"
    
    def test_default_values(self):
        """Test default port and paths."""
        endpoint = RobotEndpoint(
            id="robot-001",
            name="StairBot",
            host="192.168.1.100",
        )
        assert endpoint.port == 8000
        assert endpoint.base_path == "/api/v1"
        assert endpoint.ws_path == "/ws/status"
    
    def test_hostname_validation(self):
        """Test valid hostname formats."""
        # IP address
        endpoint = RobotEndpoint(
            id="r1",
            name="Robot",
            host="10.0.0.1",
        )
        assert endpoint.host == "10.0.0.1"
        
        # Hostname
        endpoint = RobotEndpoint(
            id="r2",
            name="Robot",
            host="robot-1.local",
        )
        assert endpoint.host == "robot-1.local"
        
        # Localhost
        endpoint = RobotEndpoint(
            id="r3",
            name="Robot",
            host="localhost",
        )
        assert endpoint.host == "localhost"
    
    def test_invalid_hostname(self):
        """Test invalid hostname rejected."""
        with pytest.raises(ValidationError):
            RobotEndpoint(
                id="robot-001",
                name="Robot",
                host="not a valid host!",
            )
    
    def test_port_range(self):
        """Test port range validation."""
        # Valid port
        endpoint = RobotEndpoint(
            id="r1",
            name="Robot",
            host="localhost",
            port=443,
        )
        assert endpoint.port == 443
        
        # Invalid port (too high)
        with pytest.raises(ValidationError):
            RobotEndpoint(
                id="r1",
                name="Robot",
                host="localhost",
                port=70000,
            )
        
        # Invalid port (too low)
        with pytest.raises(ValidationError):
            RobotEndpoint(
                id="r1",
                name="Robot",
                host="localhost",
                port=0,
            )
    
    def test_path_normalization(self):
        """Test paths start with /."""
        endpoint = RobotEndpoint(
            id="r1",
            name="Robot",
            host="localhost",
            base_path="api/v1",  # Missing leading /
            ws_path="ws/status",
        )
        assert endpoint.base_path == "/api/v1"
        assert endpoint.ws_path == "/ws/status"
    
    def test_id_length_limit(self):
        """Test ID length limit."""
        with pytest.raises(ValidationError):
            RobotEndpoint(
                id="x" * 51,
                name="Robot",
                host="localhost",
            )
    
    def test_name_length_limit(self):
        """Test name length limit."""
        with pytest.raises(ValidationError):
            RobotEndpoint(
                id="r1",
                name="x" * 101,
                host="localhost",
            )


class TestRobotStatus:
    """Tests for RobotStatus schema."""
    
    def test_valid_status(self):
        """Test valid robot status."""
        status = RobotStatus(
            id="robot-001",
            status_message="Idle",
            battery=85,
            floor=2,
            zone="A1",
            is_online=True,
            last_seen=datetime.utcnow(),
        )
        assert status.id == "robot-001"
        assert status.battery == 85
        assert status.floor == 2
    
    def test_minimal_status(self):
        """Test minimal status with only ID."""
        status = RobotStatus(id="robot-001")
        assert status.id == "robot-001"
        assert status.battery is None
        assert status.floor is None
        assert status.is_online is True  # Default
    
    def test_battery_range(self):
        """Test battery percentage range."""
        # Valid values
        for battery in [0, 50, 100]:
            status = RobotStatus(id="r1", battery=battery)
            assert status.battery == battery
        
        # Invalid (too high)
        with pytest.raises(ValidationError):
            RobotStatus(id="r1", battery=101)
        
        # Invalid (negative)
        with pytest.raises(ValidationError):
            RobotStatus(id="r1", battery=-1)
    
    def test_floor_range(self):
        """Test floor number range."""
        # Valid floors (including basement)
        for floor in [-5, 0, 1, 100]:
            status = RobotStatus(id="r1", floor=floor)
            assert status.floor == floor
        
        # Invalid (too low)
        with pytest.raises(ValidationError):
            RobotStatus(id="r1", floor=-11)
    
    def test_status_message_length(self):
        """Test status message length limit."""
        with pytest.raises(ValidationError):
            RobotStatus(
                id="r1",
                status_message="x" * 501,
            )


class TestCommandRequest:
    """Tests for CommandRequest schema."""
    
    def test_valid_directions(self):
        """Test all valid directions."""
        valid_directions = [
            "forward",
            "backward",
            "left",
            "right",
            "stop",
            "up",
            "down",
        ]
        for direction in valid_directions:
            cmd = CommandRequest(direction=direction)
            assert cmd.direction == direction
    
    def test_invalid_direction(self):
        """Test invalid direction rejected."""
        with pytest.raises(ValidationError):
            CommandRequest(direction="diagonal")
    
    def test_default_speed(self):
        """Test default speed is 1.0."""
        cmd = CommandRequest(direction="forward")
        assert cmd.speed == 1.0
    
    def test_speed_range(self):
        """Test speed range validation."""
        # Valid speeds
        for speed in [0.0, 0.5, 1.0]:
            cmd = CommandRequest(direction="forward", speed=speed)
            assert cmd.speed == speed
        
        # Invalid (too high)
        with pytest.raises(ValidationError):
            CommandRequest(direction="forward", speed=1.5)
        
        # Invalid (negative)
        with pytest.raises(ValidationError):
            CommandRequest(direction="forward", speed=-0.1)
    
    def test_duration_optional(self):
        """Test duration is optional."""
        cmd = CommandRequest(direction="forward")
        assert cmd.duration_ms is None
    
    def test_duration_range(self):
        """Test duration range validation."""
        # Valid durations
        cmd = CommandRequest(direction="forward", duration_ms=5000)
        assert cmd.duration_ms == 5000
        
        # Invalid (too long)
        with pytest.raises(ValidationError):
            CommandRequest(direction="forward", duration_ms=15000)
        
        # Invalid (negative)
        with pytest.raises(ValidationError):
            CommandRequest(direction="forward", duration_ms=-100)
