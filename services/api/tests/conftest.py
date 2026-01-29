"""
Pytest configuration and fixtures for StairDOC API tests.

Provides:
- Test database setup
- FastAPI test client
- Authentication helpers
- Factory fixtures for test data
"""

import asyncio
import os
from datetime import datetime, timedelta
from typing import AsyncGenerator, Generator
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker
from sqlmodel import SQLModel

# Set test environment before importing app modules
# SECRET_KEY must be at least 32 characters for production validation
os.environ["SECRET_KEY"] = "test-secret-key-for-testing-only-minimum-32-chars-required"
os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///./test.db"
os.environ["RATE_LIMIT_ENABLED"] = "false"
os.environ["LOG_LEVEL"] = "WARNING"
os.environ["ENVIRONMENT"] = "development"

from app.core.config import Settings, get_settings
from app.core.database import get_session
from app.core.security import create_access_token, hash_password
from app.main import app
from app.models.user import User


# =============================================================================
# Test Database Engine
# =============================================================================

TEST_DATABASE_URL = "sqlite+aiosqlite:///./test.db"

test_engine = create_async_engine(
    TEST_DATABASE_URL,
    echo=False,
    connect_args={"check_same_thread": False},
)

TestSessionLocal = sessionmaker(
    bind=test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


# =============================================================================
# Settings Override
# =============================================================================

def get_test_settings() -> Settings:
    """Get test settings."""
    return Settings(
        SECRET_KEY="test-secret-key-for-testing-only-not-production",
        DATABASE_URL=TEST_DATABASE_URL,
        RATE_LIMIT_ENABLED=False,
        LOG_LEVEL="WARNING",
    )


# =============================================================================
# Database Fixtures
# =============================================================================

@pytest.fixture(scope="session")
def event_loop() -> Generator:
    """Create event loop for async tests."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="function")
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Create a fresh database session for each test."""
    # Create tables
    async with test_engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.create_all)
    
    # Create session
    async with TestSessionLocal() as session:
        yield session
        await session.rollback()
    
    # Drop tables after test
    async with test_engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.drop_all)


@pytest.fixture
async def override_get_session(db_session: AsyncSession):
    """Override database session dependency."""
    async def _get_session():
        yield db_session
    return _get_session


# =============================================================================
# FastAPI Test Client
# =============================================================================

@pytest.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Create async test client with overridden dependencies."""
    
    async def override_session():
        yield db_session
    
    app.dependency_overrides[get_session] = override_session
    app.dependency_overrides[get_settings] = get_test_settings
    
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as ac:
        yield ac
    
    app.dependency_overrides.clear()


# =============================================================================
# User Fixtures
# =============================================================================

@pytest.fixture
async def test_user(db_session: AsyncSession) -> User:
    """Create a test user."""
    user = User(
        id="test-user-id-001",
        email="test@example.com",
        full_name="Test User",
        hashed_password=hash_password("TestPassword123!"),
        role="operator",
        created_at=datetime.utcnow(),
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def admin_user(db_session: AsyncSession) -> User:
    """Create an admin user."""
    user = User(
        id="admin-user-id-001",
        email="admin@example.com",
        full_name="Admin User",
        hashed_password=hash_password("AdminPassword123!"),
        role="admin",
        created_at=datetime.utcnow(),
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
def user_token(test_user: User) -> str:
    """Create access token for test user."""
    return create_access_token(
        data={"sub": test_user.id, "role": test_user.role},
    )


@pytest.fixture
def admin_token(admin_user: User) -> str:
    """Create access token for admin user."""
    return create_access_token(
        data={"sub": admin_user.id, "role": admin_user.role},
    )


@pytest.fixture
def auth_headers(user_token: str) -> dict:
    """Create authorization headers."""
    return {"Authorization": f"Bearer {user_token}"}


@pytest.fixture
def admin_headers(admin_token: str) -> dict:
    """Create admin authorization headers."""
    return {"Authorization": f"Bearer {admin_token}"}


# =============================================================================
# Mock Fixtures
# =============================================================================

@pytest.fixture
def mock_redis():
    """Mock Redis client."""
    mock = AsyncMock()
    mock.get = AsyncMock(return_value=None)
    mock.set = AsyncMock(return_value=True)
    mock.delete = AsyncMock(return_value=1)
    mock.exists = AsyncMock(return_value=0)
    return mock


@pytest.fixture
def mock_robot_api():
    """Mock robot API client."""
    mock = AsyncMock()
    mock.get_status = AsyncMock(return_value={
        "id": "robot-001",
        "battery": 85,
        "floor": 2,
        "zone": "A1",
        "is_online": True,
    })
    mock.send_command = AsyncMock(return_value={"success": True})
    mock.lock_container = AsyncMock(return_value={"locked": True})
    mock.unlock_container = AsyncMock(return_value={"locked": False})
    return mock


# =============================================================================
# Test Data Helpers
# =============================================================================

@pytest.fixture
def valid_user_data() -> dict:
    """Valid user registration data."""
    return {
        "email": "newuser@example.com",
        "full_name": "New User",
        "password": "SecurePass123!",
        "role": "operator",
    }


@pytest.fixture
def valid_delivery_data() -> dict:
    """Valid delivery job data."""
    return {
        "title": "Document delivery to HR",
        "pickup_zone": "FLOOR1-A",
        "dropoff_zone": "FLOOR2-B",
        "requested_by": "test-user-id-001",
    }


@pytest.fixture
def valid_voice_command() -> dict:
    """Valid voice command data."""
    return {
        "transcript": "Go to floor 3",
        "confidence": 0.95,
        "locale": "en-US",
    }
