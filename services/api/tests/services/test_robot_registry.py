"""
Unit tests for robot registry service.

Tests:
- Robot registration
- Robot lookup
- Robot status management
"""

import pytest
from datetime import datetime
from unittest.mock import MagicMock, patch

from app.services.robot_registry import RobotRegistry, robot_registry
from app.schemas.robot import RobotEndpoint, RobotStatus


class TestRobotRegistry:
    """Tests for RobotRegistry class."""
    
    def test_registry_creation(self):
        """Test that RobotRegistry can be instantiated."""
        registry = RobotRegistry()
        assert registry is not None
    
    def test_register_endpoint(self):
        """Test registering a robot endpoint."""
        registry = RobotRegistry()
        
        endpoint = RobotEndpoint(
            id="robot-001",
            name="StairDOC Unit 1",
            host="192.168.1.100",
            port=8080,
        )
        registry.register_endpoint(endpoint)
        
        assert "robot-001" in registry._endpoints
        assert registry._endpoints["robot-001"] == endpoint
    
    def test_list_endpoints(self):
        """Test listing all registered endpoints."""
        registry = RobotRegistry()
        
        endpoint1 = RobotEndpoint(id="robot-001", name="Unit 1", host="192.168.1.100")
        endpoint2 = RobotEndpoint(id="robot-002", name="Unit 2", host="192.168.1.101")
        
        registry.register_endpoint(endpoint1)
        registry.register_endpoint(endpoint2)
        
        endpoints = list(registry.list_endpoints())
        assert len(endpoints) == 2
    
    def test_update_status(self):
        """Test updating robot status."""
        registry = RobotRegistry()
        
        status = RobotStatus(
            id="robot-001",
            status_message="idle",
            floor=1,
            battery=100,
        )
        registry.update_status(status)
        
        assert "robot-001" in registry._status
    
    def test_update_status_sets_last_seen(self):
        """Test that update_status sets last_seen if not provided."""
        registry = RobotRegistry()
        
        status = RobotStatus(
            id="robot-002",
            status_message="moving",
            floor=2,
            battery=80,
        )
        registry.update_status(status)
        
        stored_status = registry._status["robot-002"]
        assert stored_status.last_seen is not None
    
    def test_get_status(self):
        """Test getting a robot's status."""
        registry = RobotRegistry()
        
        status = RobotStatus(
            id="robot-003",
            status_message="charging",
            floor=0,
            battery=50,
        )
        registry.update_status(status)
        
        result = registry.get_status("robot-003")
        assert result is not None
        assert result.status_message == "charging"
    
    def test_get_status_nonexistent(self):
        """Test getting status for non-existent robot."""
        registry = RobotRegistry()
        result = registry.get_status("nonexistent-robot")
        assert result is None
    
    def test_list_status(self):
        """Test listing all robot statuses."""
        registry = RobotRegistry()
        
        status1 = RobotStatus(id="robot-001", status_message="idle", floor=1, battery=100)
        status2 = RobotStatus(id="robot-002", status_message="moving", floor=2, battery=80)
        
        registry.update_status(status1)
        registry.update_status(status2)
        
        statuses = list(registry.list_status())
        assert len(statuses) == 2


class TestGlobalRegistry:
    """Tests for global robot_registry instance."""
    
    def test_global_registry_exists(self):
        """Test that global robot_registry is available."""
        assert robot_registry is not None
        assert isinstance(robot_registry, RobotRegistry)
    
    def test_global_registry_is_singleton_like(self):
        """Test that robot_registry can be used directly."""
        # It's a module-level instance
        assert hasattr(robot_registry, 'register_endpoint')
        assert hasattr(robot_registry, 'get_status')
        assert hasattr(robot_registry, 'list_endpoints')
