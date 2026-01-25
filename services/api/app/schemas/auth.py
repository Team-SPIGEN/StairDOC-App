"""
Authentication schemas with strict validation.

Implements:
- Strong password requirements
- Email format validation
- Input sanitization patterns
- Role validation
"""

import re
from datetime import datetime
from typing import Annotated, Literal, Optional

from pydantic import BaseModel, EmailStr, Field, field_validator

# Valid user roles
VALID_ROLES = {"admin", "operator", "viewer"}

# Password validation pattern (min 8 chars, 1 upper, 1 lower, 1 digit, 1 special)
PASSWORD_PATTERN = re.compile(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,128}$'
)

# Name validation (letters, spaces, hyphens only)
NAME_PATTERN = re.compile(r'^[a-zA-Z\s\-\'\.]{1,100}$')


class UserBase(BaseModel):
    email: EmailStr = Field(..., description="User email address")
    full_name: Annotated[
        Optional[str],
        Field(None, min_length=1, max_length=100, description="User's full name"),
    ]
    role: Literal["admin", "operator", "viewer"] = Field(
        default="operator",
        description="User role for access control",
    )
    
    @field_validator("full_name")
    @classmethod
    def validate_full_name(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        v = v.strip()
        if not NAME_PATTERN.match(v):
            raise ValueError("Name can only contain letters, spaces, hyphens, apostrophes, and periods")
        return v


class UserCreate(UserBase):
    password: Annotated[
        str,
        Field(
            ...,
            min_length=8,
            max_length=128,
            description="Strong password (8+ chars, uppercase, lowercase, digit, special)",
        ),
    ]
    
    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if not PASSWORD_PATTERN.match(v):
            raise ValueError(
                "Password must be 8-128 characters and include at least one "
                "uppercase letter, one lowercase letter, one digit, and one "
                "special character (@$!%*?&)"
            )
        return v


class UserRead(UserBase):
    id: str = Field(..., description="Unique user identifier")
    created_at: datetime = Field(..., description="Account creation timestamp")


class UserUpdate(BaseModel):
    full_name: Annotated[
        Optional[str],
        Field(None, min_length=1, max_length=100),
    ]
    password: Annotated[
        Optional[str],
        Field(None, min_length=8, max_length=128),
    ]
    
    @field_validator("full_name")
    @classmethod
    def validate_full_name(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        v = v.strip()
        if not NAME_PATTERN.match(v):
            raise ValueError("Name can only contain letters, spaces, hyphens, apostrophes, and periods")
        return v
    
    @field_validator("password")
    @classmethod
    def validate_password(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        if not PASSWORD_PATTERN.match(v):
            raise ValueError(
                "Password must be 8-128 characters and include at least one "
                "uppercase letter, one lowercase letter, one digit, and one "
                "special character (@$!%*?&)"
            )
        return v


class UserLogin(BaseModel):
    email: EmailStr = Field(..., description="User email address")
    password: Annotated[
        str,
        Field(..., min_length=1, max_length=128, description="User password"),
    ]


class TokenPayload(BaseModel):
    sub: str = Field(..., description="Subject (user ID)")
    role: str = Field(..., description="User role")
    type: Literal["access", "refresh"] = Field(..., description="Token type")
    exp: int = Field(..., description="Expiration timestamp")


class AuthToken(BaseModel):
    access_token: str = Field(..., description="JWT access token")
    refresh_token: str = Field(..., description="JWT refresh token")
    token_type: Literal["bearer"] = Field(default="bearer")
    user: UserRead = Field(..., description="Authenticated user info")


class RefreshRequest(BaseModel):
    refresh_token: Annotated[
        str,
        Field(..., min_length=10, description="JWT refresh token"),
    ]


class PasswordResetRequest(BaseModel):
    email: EmailStr = Field(..., description="Email for password reset")
