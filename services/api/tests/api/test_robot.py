"""
Integration tests for robot endpoints.

Tests:
- Robot discovery
- Robot registration  
- Status updates
- Commands
- Container control
"""

import pytest
from httpx import AsyncClient


class TestRobotDiscovery:
    """Tests for robot discovery endpoint."""
    
    @pytest.mark.asyncio
    async def test_list_robot_endpoints(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test listing robot endpoints."""
        response = await client.get(
            "/api/v1/robot/discovery",
            headers=auth_headers,
        )
        assert response.status_code == 200
        assert isinstance(response.json(), list)
    
    @pytest.mark.asyncio
    async def test_discovery_without_auth(self, client: AsyncClient):
        """Test discovery endpoint requires auth."""
        response = await client.get("/api/v1/robot/discovery")
        assert response.status_code in [401, 403]


class TestRobotRegistration:
    """Tests for robot registration endpoint."""
    
    @pytest.mark.asyncio
    async def test_register_robot(self, client: AsyncClient):
        """Test registering a new robot."""
        response = await client.post(
            "/api/v1/robot/register",
            json={
                "id": "test-robot-001",
                "name": "Test Robot",
                "host": "192.168.1.100",
                "port": 8000,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == "test-robot-001"


class TestRobotStatus:
    """Tests for robot status endpoints."""
    
    @pytest.mark.asyncio
    async def test_update_robot_status(self, client: AsyncClient):
        """Test updating robot status."""
        response = await client.post(
            "/api/v1/robot/status",
            json={
                "id": "test-robot-001",
                "status_message": "idle",
                "battery": 100,
                "floor": 1,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == "test-robot-001"
        assert data["status_message"] == "idle"


class TestRobotCommands:
    """Tests for robot command endpoints."""
    
    @pytest.mark.asyncio
    async def test_send_valid_command(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test sending valid movement command."""
        response = await client.post(
            "/api/v1/robot/command",
            json={"direction": "forward"},
            headers=auth_headers,
        )
        # May succeed or fail if no robot connected
        assert response.status_code in [200, 201, 503, 404]
    
    @pytest.mark.asyncio
    async def test_send_command_with_speed(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test sending command with speed parameter."""
        response = await client.post(
            "/api/v1/robot/command",
            json={"direction": "forward", "speed": 0.5},
            headers=auth_headers,
        )
        assert response.status_code in [200, 201, 503, 404]
    
    @pytest.mark.asyncio
    async def test_send_invalid_direction(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test sending invalid direction fails."""
        response = await client.post(
            "/api/v1/robot/command",
            json={"direction": "invalid"},
            headers=auth_headers,
        )
        assert response.status_code == 422
    
    @pytest.mark.asyncio
    async def test_send_stop_command(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test sending stop command."""
        response = await client.post(
            "/api/v1/robot/command",
            json={"direction": "stop"},
            headers=auth_headers,
        )
        assert response.status_code in [200, 201, 503, 404]
    
    @pytest.mark.asyncio
    async def test_command_without_auth(self, client: AsyncClient):
        """Test command endpoint requires auth."""
        response = await client.post(
            "/api/v1/robot/command",
            json={"direction": "forward"},
        )
        assert response.status_code in [401, 403]


class TestContainerControl:
    """Tests for container lock/unlock endpoints."""
    
    @pytest.mark.asyncio
    async def test_lock_container(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test locking container."""
        response = await client.post(
            "/api/v1/container/lock",
            json={"location": "Floor 2", "method": "app"},
            headers=auth_headers,
        )
        assert response.status_code in [200, 201, 503, 404]
    
    @pytest.mark.asyncio
    async def test_unlock_container(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test unlocking container."""
        response = await client.post(
            "/api/v1/container/unlock",
            json={"location": "Floor 2", "method": "app"},
            headers=auth_headers,
        )
        assert response.status_code in [200, 201, 503, 404]
    
    @pytest.mark.asyncio
    async def test_get_container_status(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test getting container status."""
        response = await client.get(
            "/api/v1/container/status",
            headers=auth_headers,
        )
        assert response.status_code in [200, 404, 503]
    
    @pytest.mark.asyncio
    async def test_container_without_auth(self, client: AsyncClient):
        """Test container endpoints require auth."""
        response = await client.post(
            "/api/v1/container/lock",
            json={"location": "Floor 2"},
        )
        assert response.status_code in [401, 403]


class TestAccessLogs:
    """Tests for access log endpoints."""
    
    @pytest.mark.asyncio
    async def test_get_access_logs(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test getting access logs."""
        response = await client.get(
            "/api/v1/container/logs",
            headers=auth_headers,
        )
        assert response.status_code in [200, 404]
    
    @pytest.mark.asyncio
    async def test_get_access_logs_paginated(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test getting paginated access logs."""
        response = await client.get(
            "/api/v1/container/logs?limit=10&offset=0",
            headers=auth_headers,
        )
        assert response.status_code in [200, 404]
    
    @pytest.mark.asyncio
    async def test_access_logs_without_auth(self, client: AsyncClient):
        """Test access logs require auth."""
        response = await client.get("/api/v1/container/logs")
        assert response.status_code in [401, 403]
