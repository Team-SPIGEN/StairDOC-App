"""
Pydantic schemas for container access control endpoints.

These schemas define the request/response contracts for:
- Lock/unlock operations
- Access log retrieval
- Container status queries

Implements strict validation for security-sensitive operations.
"""

import re
from datetime import datetime
from typing import Annotated, Optional, List
from enum import Enum

from pydantic import BaseModel, Field, field_validator, HttpUrl


class ContainerAction(str, Enum):
    """Valid container actions."""
    LOCK = "lock"
    UNLOCK = "unlock"


class AccessMethod(str, Enum):
    """How the access action was triggered."""
    APP = "app"
    RFID = "rfid"
    VOICE = "voice"
    AUTO = "auto"


class AccessStatus(str, Enum):
    """Outcome of an access action."""
    SUCCESS = "success"
    FAILED = "failed"
    DENIED = "denied"


# Zone pattern validation
ZONE_PATTERN = re.compile(r'^[A-Z0-9_\-]{1,20}$', re.IGNORECASE)
LOCATION_PATTERN = re.compile(r'^[a-zA-Z0-9\s\-\'\.]{1,100}$')


class LockUnlockRequest(BaseModel):
    """Request body for lock/unlock operations."""
    location: Annotated[
        Optional[str],
        Field(
            default=None,
            max_length=100,
            description="Human-readable location (e.g., 'Floor 2 - Office 201')"
        ),
    ]
    floor: Annotated[
        Optional[int],
        Field(
            default=None,
            ge=-5,
            le=200,
            description="Floor number"
        ),
    ]
    zone: Annotated[
        Optional[str],
        Field(
            default=None,
            max_length=20,
            description="Zone identifier within floor"
        ),
    ]
    method: AccessMethod = Field(
        default=AccessMethod.APP,
        description="How the action was triggered"
    )
    
    @field_validator("location")
    @classmethod
    def validate_location(cls, v: Optional[str]) -> Optional[str]:
        """Validate and sanitize location string."""
        if v is None:
            return v
        v = v.strip()
        if not LOCATION_PATTERN.match(v):
            raise ValueError("Location contains invalid characters")
        return v
    
    @field_validator("zone")
    @classmethod
    def validate_zone(cls, v: Optional[str]) -> Optional[str]:
        """Validate zone format."""
        if v is None:
            return v
        v = v.strip().upper()
        if not ZONE_PATTERN.match(v):
            raise ValueError(
                "Zone must be 1-20 characters containing only letters, "
                "numbers, underscores, and hyphens"
            )
        return v


class LockUnlockResponse(BaseModel):
    """Response from lock/unlock operations."""
    status: str = Field(..., description="Operation result status")
    action: ContainerAction = Field(..., description="Action performed")
    timestamp: datetime = Field(..., description="Action timestamp")
    message: str = Field(..., max_length=500, description="Status message")
    log_id: int = Field(..., ge=1, description="Access log entry ID")


class AccessLogResponse(BaseModel):
    """Single access log entry for API response."""
    id: int = Field(..., ge=1)
    user_id: str = Field(..., max_length=50)
    user_name: str = Field(..., max_length=100)
    action: str = Field(..., max_length=20)
    location: str = Field(..., max_length=100)
    floor: Optional[int] = Field(None, ge=-5, le=200)
    zone: Optional[str] = Field(None, max_length=20)
    timestamp: datetime
    status: str = Field(..., max_length=20)
    error_message: Optional[str] = Field(None, max_length=500)
    photo_url: Optional[str] = Field(None, max_length=500)
    method: str = Field(..., max_length=20)

    class Config:
        from_attributes = True


class AccessLogListResponse(BaseModel):
    """Paginated list of access logs."""
    logs: List[AccessLogResponse] = Field(..., description="List of access log entries")
    total: int = Field(..., ge=0, description="Total number of logs")
    limit: int = Field(..., ge=1, le=100, description="Page size limit")
    offset: int = Field(..., ge=0, description="Pagination offset")
    has_more: bool = Field(..., description="Whether more results exist")


class ContainerStatusResponse(BaseModel):
    """Current container lock status."""
    is_locked: bool = Field(..., description="Current lock state")
    last_action: Optional[str] = Field(None, max_length=20)
    last_action_by: Optional[str] = Field(None, max_length=100)
    last_action_at: Optional[datetime] = None
    robot_id: Optional[str] = Field(None, max_length=50)
