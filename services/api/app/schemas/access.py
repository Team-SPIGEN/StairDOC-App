"""
Pydantic schemas for container access control endpoints.

These schemas define the request/response contracts for:
- Lock/unlock operations
- Access log retrieval
- Container status queries
"""

from datetime import datetime
from typing import Optional, List
from enum import Enum

from pydantic import BaseModel, Field


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


class LockUnlockRequest(BaseModel):
    """Request body for lock/unlock operations."""
    location: Optional[str] = Field(
        default=None,
        description="Human-readable location (e.g., 'Floor 2 - Office 201')"
    )
    floor: Optional[int] = Field(
        default=None,
        ge=1,
        le=10,
        description="Floor number (1-10)"
    )
    zone: Optional[str] = Field(
        default=None,
        description="Zone identifier within floor"
    )
    method: AccessMethod = Field(
        default=AccessMethod.APP,
        description="How the action was triggered"
    )


class LockUnlockResponse(BaseModel):
    """Response from lock/unlock operations."""
    status: str
    action: ContainerAction
    timestamp: datetime
    message: str
    log_id: int


class AccessLogResponse(BaseModel):
    """Single access log entry for API response."""
    id: int
    user_id: str
    user_name: str
    action: str
    location: str
    floor: Optional[int] = None
    zone: Optional[str] = None
    timestamp: datetime
    status: str
    error_message: Optional[str] = None
    photo_url: Optional[str] = None
    method: str

    class Config:
        from_attributes = True


class AccessLogListResponse(BaseModel):
    """Paginated list of access logs."""
    logs: List[AccessLogResponse]
    total: int
    limit: int
    offset: int
    has_more: bool


class ContainerStatusResponse(BaseModel):
    """Current container lock status."""
    is_locked: bool
    last_action: Optional[str] = None
    last_action_by: Optional[str] = None
    last_action_at: Optional[datetime] = None
    robot_id: Optional[str] = None
