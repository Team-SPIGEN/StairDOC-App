"""
Unit tests for security module.

Tests:
- Password hashing
- JWT token creation and validation
- Token refresh
"""

import pytest
from datetime import datetime, timedelta
from unittest.mock import patch

from app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    decode_token,
)


class TestPasswordHashing:
    """Tests for password hashing functions."""
    
    def test_hash_password(self):
        """Test password hashing creates different output."""
        password = "SecurePassword123!"
        hashed = hash_password(password)
        
        assert hashed != password
        assert len(hashed) > 0
    
    def test_hash_is_unique(self):
        """Test same password creates different hashes."""
        password = "SecurePassword123!"
        hash1 = hash_password(password)
        hash2 = hash_password(password)
        
        # Bcrypt uses different salt each time
        assert hash1 != hash2
    
    def test_verify_correct_password(self):
        """Test verifying correct password."""
        password = "SecurePassword123!"
        hashed = hash_password(password)
        
        assert verify_password(password, hashed) is True
    
    def test_verify_wrong_password(self):
        """Test verifying wrong password."""
        password = "SecurePassword123!"
        hashed = hash_password(password)
        
        assert verify_password("WrongPassword123!", hashed) is False
    
    def test_verify_similar_password(self):
        """Test similar passwords don't match."""
        password = "SecurePassword123!"
        hashed = hash_password(password)
        
        # Case difference
        assert verify_password("securepassword123!", hashed) is False
        # Extra character
        assert verify_password("SecurePassword123!!", hashed) is False
    
    def test_empty_password(self):
        """Test empty password can be hashed and verified."""
        password = ""
        hashed = hash_password(password)
        
        assert verify_password("", hashed) is True
        assert verify_password("something", hashed) is False


class TestAccessToken:
    """Tests for access token creation and validation."""
    
    def test_create_access_token(self):
        """Test creating access token."""
        token = create_access_token(
            data={"sub": "user-123", "role": "operator"},
        )
        
        assert token is not None
        assert len(token) > 0
        assert "." in token  # JWT format
    
    def test_access_token_parts(self):
        """Test access token has three parts."""
        token = create_access_token(
            data={"sub": "user-123", "role": "operator"},
        )
        
        parts = token.split(".")
        assert len(parts) == 3  # header.payload.signature
    
    def test_decode_valid_token(self):
        """Test decoding valid token."""
        token = create_access_token(
            data={"sub": "user-123", "role": "operator"},
        )
        
        payload = decode_token(token)
        
        assert payload is not None
        assert payload.get("sub") == "user-123"
        assert payload.get("role") == "operator"
        assert payload.get("type") == "access"
    
    def test_token_has_expiry(self):
        """Test token has expiration claim."""
        token = create_access_token(
            data={"sub": "user-123", "role": "operator"},
        )
        
        payload = decode_token(token)
        
        assert "exp" in payload
        assert payload["exp"] > datetime.utcnow().timestamp()
    
    def test_decode_invalid_token(self):
        """Test decoding invalid token raises error."""
        with pytest.raises(ValueError):
            decode_token("invalid.token.here")
    
    def test_decode_tampered_token(self):
        """Test decoding tampered token fails."""
        token = create_access_token(
            data={"sub": "user-123", "role": "operator"},
        )
        
        # Tamper with token
        parts = token.split(".")
        parts[1] = parts[1] + "tampered"
        tampered = ".".join(parts)
        
        with pytest.raises(ValueError):
            decode_token(tampered)


class TestRefreshToken:
    """Tests for refresh token creation and validation."""
    
    def test_create_refresh_token(self):
        """Test creating refresh token."""
        token = create_access_token(
            data={"sub": "user-123", "role": "operator"},
            token_type="refresh",
        )
        
        assert token is not None
        assert len(token) > 0
    
    def test_refresh_token_type(self):
        """Test refresh token has correct type."""
        token = create_access_token(
            data={"sub": "user-123", "role": "operator"},
            token_type="refresh",
        )
        
        payload = decode_token(token)
        
        assert payload.get("type") == "refresh"


class TestTokenValidation:
    """Tests for token validation edge cases."""
    
    def test_decode_empty_token(self):
        """Test decoding empty token."""
        with pytest.raises(ValueError):
            decode_token("")
    
    def test_decode_malformed_token(self):
        """Test decoding malformed token."""
        with pytest.raises(ValueError):
            decode_token("not.a.valid.jwt.token")
    
    def test_token_different_subjects(self):
        """Test tokens for different users have different subjects."""
        token1 = create_access_token(data={"sub": "user-1", "role": "operator"})
        token2 = create_access_token(data={"sub": "user-2", "role": "operator"})
        
        payload1 = decode_token(token1)
        payload2 = decode_token(token2)
        
        assert payload1["sub"] != payload2["sub"]
    
    def test_token_different_roles(self):
        """Test tokens capture different roles."""
        token_operator = create_access_token(data={"sub": "user-1", "role": "operator"})
        token_admin = create_access_token(data={"sub": "user-1", "role": "admin"})
        
        payload_operator = decode_token(token_operator)
        payload_admin = decode_token(token_admin)
        
        assert payload_operator["role"] == "operator"
        assert payload_admin["role"] == "admin"
