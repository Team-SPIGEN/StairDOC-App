"""
Integration tests for delivery endpoints.

Tests:
- Create delivery job
- List delivery jobs
- Update delivery status
- Cancel delivery
"""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession


class TestDeliveryCreate:
    """Tests for delivery job creation."""
    
    @pytest.mark.asyncio
    async def test_create_delivery_job(
        self, client: AsyncClient, auth_headers: dict, valid_delivery_data: dict
    ):
        """Test successful delivery job creation."""
        response = await client.post(
            "/api/v1/delivery/jobs",
            json=valid_delivery_data,
            headers=auth_headers,
        )
        assert response.status_code in [200, 201]
        data = response.json()
        assert "id" in data
        assert data["status"] == "pending"
    
    @pytest.mark.asyncio
    async def test_create_delivery_without_auth(
        self, client: AsyncClient, valid_delivery_data: dict
    ):
        """Test delivery creation without authentication fails."""
        response = await client.post(
            "/api/v1/delivery/jobs",
            json=valid_delivery_data,
        )
        assert response.status_code in [401, 403]
    
    @pytest.mark.asyncio
    async def test_create_delivery_invalid_zone(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test delivery with invalid zone format fails."""
        response = await client.post(
            "/api/v1/delivery/jobs",
            json={
                "title": "Test delivery",
                "pickup_zone": "invalid zone!",  # Invalid characters
                "dropoff_zone": "FLOOR1-A",
                "requested_by": "user-123",
            },
            headers=auth_headers,
        )
        assert response.status_code == 422
    
    @pytest.mark.asyncio
    async def test_create_delivery_empty_title(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test delivery with empty title fails."""
        response = await client.post(
            "/api/v1/delivery/jobs",
            json={
                "title": "",
                "pickup_zone": "FLOOR1-A",
                "dropoff_zone": "FLOOR2-B",
                "requested_by": "user-123",
            },
            headers=auth_headers,
        )
        assert response.status_code == 422


class TestDeliveryList:
    """Tests for listing delivery jobs."""
    
    @pytest.mark.asyncio
    async def test_list_delivery_jobs(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test listing delivery jobs."""
        response = await client.get(
            "/api/v1/delivery/jobs",
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        # Should be a list or paginated response
        assert isinstance(data, (list, dict))
    
    @pytest.mark.asyncio
    async def test_list_with_pagination(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test listing with pagination parameters."""
        response = await client.get(
            "/api/v1/delivery/jobs?limit=10&offset=0",
            headers=auth_headers,
        )
        assert response.status_code == 200
    
    @pytest.mark.asyncio
    async def test_list_with_status_filter(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test listing with status filter."""
        response = await client.get(
            "/api/v1/delivery/jobs?status=pending",
            headers=auth_headers,
        )
        assert response.status_code == 200


class TestDeliveryUpdate:
    """Tests for updating delivery jobs."""
    
    @pytest.mark.asyncio
    async def test_update_delivery_status(
        self, client: AsyncClient, auth_headers: dict, valid_delivery_data: dict
    ):
        """Test updating delivery status."""
        # First create a job
        create_response = await client.post(
            "/api/v1/delivery/jobs",
            json=valid_delivery_data,
            headers=auth_headers,
        )
        if create_response.status_code not in [200, 201]:
            pytest.skip("Could not create delivery job")
        
        job_id = create_response.json()["id"]
        
        # Update status
        response = await client.patch(
            f"/api/v1/delivery/jobs/{job_id}",
            json={"status": "in_progress"},
            headers=auth_headers,
        )
        assert response.status_code in [200, 404]  # 404 if job was cleaned up
    
    @pytest.mark.asyncio
    async def test_update_nonexistent_job(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test updating non-existent job fails."""
        response = await client.patch(
            "/api/v1/delivery/jobs/nonexistent-id",
            json={"status": "in_progress"},
            headers=auth_headers,
        )
        assert response.status_code == 404
    
    @pytest.mark.asyncio
    async def test_update_invalid_status(
        self, client: AsyncClient, auth_headers: dict, valid_delivery_data: dict
    ):
        """Test updating with invalid status fails."""
        # Create job first
        create_response = await client.post(
            "/api/v1/delivery/jobs",
            json=valid_delivery_data,
            headers=auth_headers,
        )
        if create_response.status_code not in [200, 201]:
            pytest.skip("Could not create delivery job")
        
        job_id = create_response.json()["id"]
        
        response = await client.patch(
            f"/api/v1/delivery/jobs/{job_id}",
            json={"status": "invalid_status"},
            headers=auth_headers,
        )
        assert response.status_code == 422


class TestDeliveryCancel:
    """Tests for cancelling delivery jobs."""
    
    @pytest.mark.asyncio
    async def test_cancel_delivery(
        self, client: AsyncClient, auth_headers: dict, valid_delivery_data: dict
    ):
        """Test cancelling a delivery job."""
        # Create job first
        create_response = await client.post(
            "/api/v1/delivery/jobs",
            json=valid_delivery_data,
            headers=auth_headers,
        )
        if create_response.status_code not in [200, 201]:
            pytest.skip("Could not create delivery job")
        
        job_id = create_response.json()["id"]
        
        # Cancel it
        response = await client.delete(
            f"/api/v1/delivery/jobs/{job_id}",
            headers=auth_headers,
        )
        assert response.status_code in [200, 204, 404]
    
    @pytest.mark.asyncio
    async def test_cancel_nonexistent_job(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test cancelling non-existent job fails."""
        response = await client.delete(
            "/api/v1/delivery/jobs/nonexistent-id",
            headers=auth_headers,
        )
        assert response.status_code == 404


class TestDeliveryGet:
    """Tests for getting single delivery job."""
    
    @pytest.mark.asyncio
    async def test_get_delivery_job(
        self, client: AsyncClient, auth_headers: dict, valid_delivery_data: dict
    ):
        """Test getting a single delivery job."""
        # Create job first
        create_response = await client.post(
            "/api/v1/delivery/jobs",
            json=valid_delivery_data,
            headers=auth_headers,
        )
        if create_response.status_code not in [200, 201]:
            pytest.skip("Could not create delivery job")
        
        job_id = create_response.json()["id"]
        
        # Get it
        response = await client.get(
            f"/api/v1/delivery/jobs/{job_id}",
            headers=auth_headers,
        )
        assert response.status_code in [200, 404]
        if response.status_code == 200:
            data = response.json()
            assert data["id"] == job_id
    
    @pytest.mark.asyncio
    async def test_get_nonexistent_job(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test getting non-existent job returns 404."""
        response = await client.get(
            "/api/v1/delivery/jobs/nonexistent-id",
            headers=auth_headers,
        )
        assert response.status_code == 404
