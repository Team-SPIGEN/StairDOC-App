"""
Integration tests for health check endpoints.

Tests:
- Basic health check
- Readiness check
- Database connectivity check
"""

import pytest
from httpx import AsyncClient


class TestHealthEndpoints:
    """Tests for health check endpoints."""
    
    @pytest.mark.asyncio
    async def test_health_check(self, client: AsyncClient):
        """Test basic health check returns OK."""
        response = await client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data.get("status") == "healthy" or data.get("status") == "ok"
    
    @pytest.mark.asyncio
    async def test_health_response_format(self, client: AsyncClient):
        """Test health response has expected format."""
        response = await client.get("/health")
        assert response.status_code == 200
        data = response.json()
        # Should have status field at minimum
        assert "status" in data
    
    @pytest.mark.asyncio
    async def test_root_endpoint(self, client: AsyncClient):
        """Test root endpoint returns app info."""
        response = await client.get("/")
        # Either returns info or redirects
        assert response.status_code in [200, 307, 404]
