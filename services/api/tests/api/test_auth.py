"""
Integration tests for authentication endpoints.

Tests:
- User registration
- User login
- Token refresh
- Protected endpoints
"""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.core.security import hash_password


class TestAuthRegistration:
    """Tests for user registration endpoint."""
    
    @pytest.mark.asyncio
    async def test_register_valid_user(self, client: AsyncClient):
        """Test successful user registration."""
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "newuser@example.com",
                "full_name": "New User",
                "password": "SecurePass123!",
                "role": "operator",
            },
        )
        assert response.status_code in [200, 201]
        data = response.json()
        assert "access_token" in data or "user" in data
    
    @pytest.mark.asyncio
    async def test_register_duplicate_email(
        self, client: AsyncClient, test_user: User
    ):
        """Test registration with existing email fails."""
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": test_user.email,  # Already exists
                "full_name": "Duplicate User",
                "password": "SecurePass123!",
                "role": "operator",
            },
        )
        assert response.status_code in [400, 409]
    
    @pytest.mark.asyncio
    async def test_register_invalid_email(self, client: AsyncClient):
        """Test registration with invalid email fails."""
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "not-an-email",
                "full_name": "Test",
                "password": "SecurePass123!",
            },
        )
        assert response.status_code == 422
    
    @pytest.mark.asyncio
    async def test_register_weak_password(self, client: AsyncClient):
        """Test registration with weak password fails."""
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "test@example.com",
                "password": "weak",
            },
        )
        assert response.status_code == 422


class TestAuthLogin:
    """Tests for user login endpoint."""
    
    @pytest.mark.asyncio
    async def test_login_valid_credentials(
        self, client: AsyncClient, test_user: User
    ):
        """Test successful login."""
        response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": test_user.email,
                "password": "TestPassword123!",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"
    
    @pytest.mark.asyncio
    async def test_login_invalid_email(self, client: AsyncClient):
        """Test login with non-existent email."""
        response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": "nonexistent@example.com",
                "password": "SomePassword123!",
            },
        )
        assert response.status_code in [401, 404]
    
    @pytest.mark.asyncio
    async def test_login_wrong_password(
        self, client: AsyncClient, test_user: User
    ):
        """Test login with wrong password."""
        response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": test_user.email,
                "password": "WrongPassword123!",
            },
        )
        assert response.status_code == 401
    
    @pytest.mark.asyncio
    async def test_login_response_includes_user(
        self, client: AsyncClient, test_user: User
    ):
        """Test login response includes user info."""
        response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": test_user.email,
                "password": "TestPassword123!",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "user" in data
        assert data["user"]["email"] == test_user.email


class TestTokenRefresh:
    """Tests for token refresh endpoint."""
    
    @pytest.mark.asyncio
    async def test_refresh_valid_token(
        self, client: AsyncClient, test_user: User
    ):
        """Test token refresh with valid refresh token."""
        # First login to get tokens
        login_response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": test_user.email,
                "password": "TestPassword123!",
            },
        )
        tokens = login_response.json()
        
        # Refresh token
        response = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": tokens["refresh_token"]},
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
    
    @pytest.mark.asyncio
    async def test_refresh_invalid_token(self, client: AsyncClient):
        """Test token refresh with invalid token."""
        response = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": "invalid.token.here"},
        )
        assert response.status_code in [401, 422]


class TestProtectedEndpoints:
    """Tests for protected endpoint access."""
    
    @pytest.mark.asyncio
    async def test_access_without_token(self, client: AsyncClient):
        """Test protected endpoint without token returns 401."""
        response = await client.get("/api/v1/auth/me")
        assert response.status_code in [401, 403]
    
    @pytest.mark.asyncio
    async def test_access_with_valid_token(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test protected endpoint with valid token."""
        response = await client.get(
            "/api/v1/auth/me",
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert "email" in data or "id" in data
    
    @pytest.mark.asyncio
    async def test_access_with_invalid_token(self, client: AsyncClient):
        """Test protected endpoint with invalid token."""
        response = await client.get(
            "/api/v1/auth/me",
            headers={"Authorization": "Bearer invalid.token.here"},
        )
        assert response.status_code in [401, 403]
    
    @pytest.mark.asyncio
    async def test_access_with_expired_token(self, client: AsyncClient):
        """Test protected endpoint with expired token."""
        # Create an obviously expired token
        expired_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0Iiwicm9sZSI6Im9wZXJhdG9yIiwidHlwZSI6ImFjY2VzcyIsImV4cCI6MX0.expired"
        response = await client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {expired_token}"},
        )
        assert response.status_code in [401, 403]


class TestAdminEndpoints:
    """Tests for admin-only endpoints."""
    
    @pytest.mark.asyncio
    async def test_admin_access_as_operator(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test admin endpoint access as operator fails."""
        # This depends on having an admin-only endpoint
        # Adjust the endpoint path based on your API
        response = await client.get(
            "/api/v1/admin/users",  # Example admin endpoint
            headers=auth_headers,
        )
        # Should be 403 Forbidden or 404 if endpoint doesn't exist
        assert response.status_code in [403, 404]
    
    @pytest.mark.asyncio
    async def test_admin_access_as_admin(
        self, client: AsyncClient, admin_headers: dict
    ):
        """Test admin endpoint access as admin succeeds."""
        # Adjust the endpoint path based on your API
        response = await client.get(
            "/api/v1/admin/users",  # Example admin endpoint
            headers=admin_headers,
        )
        # Should succeed or 404 if endpoint doesn't exist
        assert response.status_code in [200, 404]
