"""
Unit tests for authentication schemas.

Tests:
- User creation validation
- Password strength requirements
- Email format validation
- Role validation
"""

import pytest
from pydantic import ValidationError

from app.schemas.auth import (
    UserBase,
    UserCreate,
    UserLogin,
    UserUpdate,
    UserRead,
    TokenPayload,
    AuthToken,
    RefreshRequest,
    PasswordResetRequest,
)


class TestUserBase:
    """Tests for UserBase schema."""
    
    def test_valid_user_base(self):
        """Test valid user base data."""
        user = UserBase(
            email="test@example.com",
            full_name="Test User",
            role="operator",
        )
        assert user.email == "test@example.com"
        assert user.full_name == "Test User"
        assert user.role == "operator"
    
    def test_default_role(self):
        """Test default role is operator."""
        user = UserBase(email="test@example.com")
        assert user.role == "operator"
    
    def test_optional_full_name(self):
        """Test full name is optional."""
        user = UserBase(email="test@example.com")
        assert user.full_name is None
    
    def test_invalid_email_format(self):
        """Test invalid email format rejected."""
        with pytest.raises(ValidationError) as exc_info:
            UserBase(email="not-an-email")
        assert "email" in str(exc_info.value).lower()
    
    def test_invalid_role(self):
        """Test invalid role rejected."""
        with pytest.raises(ValidationError):
            UserBase(email="test@example.com", role="superuser")
    
    def test_valid_roles(self):
        """Test all valid roles accepted."""
        for role in ["admin", "operator", "viewer"]:
            user = UserBase(email="test@example.com", role=role)
            assert user.role == role
    
    def test_full_name_sanitized(self):
        """Test full name with valid characters."""
        user = UserBase(
            email="test@example.com",
            full_name="John O'Brien-Smith Jr.",
        )
        assert user.full_name == "John O'Brien-Smith Jr."
    
    def test_full_name_invalid_characters(self):
        """Test full name with invalid characters rejected."""
        with pytest.raises(ValidationError):
            UserBase(
                email="test@example.com",
                full_name="<script>alert('xss')</script>",
            )


class TestUserCreate:
    """Tests for UserCreate schema."""
    
    def test_valid_user_create(self):
        """Test valid user creation data."""
        user = UserCreate(
            email="new@example.com",
            full_name="New User",
            password="SecurePass123!",
            role="operator",
        )
        assert user.email == "new@example.com"
        assert user.password == "SecurePass123!"
    
    def test_password_required(self):
        """Test password is required."""
        with pytest.raises(ValidationError):
            UserCreate(email="test@example.com")
    
    def test_password_too_short(self):
        """Test short password rejected."""
        with pytest.raises(ValidationError) as exc_info:
            UserCreate(
                email="test@example.com",
                password="Short1!",  # Only 7 chars
            )
        assert "password" in str(exc_info.value).lower()
    
    def test_password_no_uppercase(self):
        """Test password without uppercase rejected."""
        with pytest.raises(ValidationError):
            UserCreate(
                email="test@example.com",
                password="lowercase123!",
            )
    
    def test_password_no_lowercase(self):
        """Test password without lowercase rejected."""
        with pytest.raises(ValidationError):
            UserCreate(
                email="test@example.com",
                password="UPPERCASE123!",
            )
    
    def test_password_no_digit(self):
        """Test password without digit rejected."""
        with pytest.raises(ValidationError):
            UserCreate(
                email="test@example.com",
                password="NoDigitsHere!",
            )
    
    def test_password_no_special(self):
        """Test password without special character rejected."""
        with pytest.raises(ValidationError):
            UserCreate(
                email="test@example.com",
                password="NoSpecial123",
            )
    
    def test_strong_password_accepted(self):
        """Test strong password is accepted."""
        user = UserCreate(
            email="test@example.com",
            password="MyStr0ng!Pass",
        )
        assert user.password == "MyStr0ng!Pass"


class TestUserLogin:
    """Tests for UserLogin schema."""
    
    def test_valid_login(self):
        """Test valid login data."""
        login = UserLogin(
            email="test@example.com",
            password="password123",
        )
        assert login.email == "test@example.com"
    
    def test_email_required(self):
        """Test email is required."""
        with pytest.raises(ValidationError):
            UserLogin(password="password123")
    
    def test_password_required(self):
        """Test password is required."""
        with pytest.raises(ValidationError):
            UserLogin(email="test@example.com")
    
    def test_empty_password_rejected(self):
        """Test empty password rejected."""
        with pytest.raises(ValidationError):
            UserLogin(email="test@example.com", password="")


class TestUserUpdate:
    """Tests for UserUpdate schema."""
    
    def test_update_full_name_only(self):
        """Test updating only full name."""
        update = UserUpdate(full_name="New Name")
        assert update.full_name == "New Name"
        assert update.password is None
    
    def test_update_password_only(self):
        """Test updating only password."""
        update = UserUpdate(password="NewSecure123!")
        assert update.password == "NewSecure123!"
        assert update.full_name is None
    
    def test_update_both_fields(self):
        """Test updating both fields."""
        update = UserUpdate(
            full_name="Updated Name",
            password="UpdatedPass123!",
        )
        assert update.full_name == "Updated Name"
        assert update.password == "UpdatedPass123!"
    
    def test_empty_update_allowed(self):
        """Test empty update is allowed."""
        update = UserUpdate()
        assert update.full_name is None
        assert update.password is None
    
    def test_weak_password_rejected(self):
        """Test weak password in update rejected."""
        with pytest.raises(ValidationError):
            UserUpdate(password="weak")


class TestTokenPayload:
    """Tests for TokenPayload schema."""
    
    def test_valid_payload(self):
        """Test valid token payload."""
        payload = TokenPayload(
            sub="user-123",
            role="operator",
            type="access",
            exp=1234567890,
        )
        assert payload.sub == "user-123"
        assert payload.role == "operator"
    
    def test_token_types(self):
        """Test valid token types."""
        for token_type in ["access", "refresh"]:
            payload = TokenPayload(
                sub="user-123",
                role="operator",
                type=token_type,
                exp=1234567890,
            )
            assert payload.type == token_type


class TestAuthToken:
    """Tests for AuthToken schema."""
    
    def test_valid_auth_token(self):
        """Test valid auth token response."""
        from datetime import datetime
        
        user = UserRead(
            id="user-123",
            email="test@example.com",
            full_name="Test User",
            role="operator",
            created_at=datetime.utcnow(),
        )
        
        token = AuthToken(
            access_token="access.token.here",
            refresh_token="refresh.token.here",
            user=user,
        )
        assert token.token_type == "bearer"
        assert token.access_token == "access.token.here"


class TestRefreshRequest:
    """Tests for RefreshRequest schema."""
    
    def test_valid_refresh_request(self):
        """Test valid refresh request."""
        request = RefreshRequest(
            refresh_token="valid.refresh.token",
        )
        assert request.refresh_token == "valid.refresh.token"
    
    def test_empty_token_rejected(self):
        """Test empty refresh token rejected."""
        with pytest.raises(ValidationError):
            RefreshRequest(refresh_token="")
    
    def test_short_token_rejected(self):
        """Test too short refresh token rejected."""
        with pytest.raises(ValidationError):
            RefreshRequest(refresh_token="short")


class TestPasswordResetRequest:
    """Tests for PasswordResetRequest schema."""
    
    def test_valid_reset_request(self):
        """Test valid password reset request."""
        request = PasswordResetRequest(email="test@example.com")
        assert request.email == "test@example.com"
    
    def test_invalid_email_rejected(self):
        """Test invalid email rejected."""
        with pytest.raises(ValidationError):
            PasswordResetRequest(email="not-an-email")
