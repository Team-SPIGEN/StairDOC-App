"""
Robot schemas with validation.

Implements:
- Endpoint validation
- Battery range validation
- Direction validation for commands
"""

import re
from datetime import datetime
from typing import Annotated, Literal, Optional

from pydantic import BaseModel, Field, field_validator

# Valid movement directions
VALID_DIRECTIONS = {"forward", "backward", "left", "right", "stop", "up", "down"}

# Hostname pattern (DNS or IP)
HOSTNAME_PATTERN = re.compile(
    r'^(?:'
    r'(?:(?:[a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*'
    r'(?:[A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])'
    r'|'
    r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
    r')$'
)


class RobotEndpoint(BaseModel):
    id: Annotated[
        str,
        Field(..., min_length=1, max_length=50, description="Unique robot identifier"),
    ]
    name: Annotated[
        str,
        Field(..., min_length=1, max_length=100, description="Human-readable robot name"),
    ]
    host: Annotated[
        str,
        Field(..., min_length=1, max_length=255, description="Robot hostname or IP address"),
    ]
    port: Annotated[
        int,
        Field(default=8000, ge=1, le=65535, description="Robot API port"),
    ]
    base_path: Annotated[
        str,
        Field(default="/api/v1", max_length=100, description="API base path"),
    ]
    ws_path: Annotated[
        str,
        Field(default="/ws/status", max_length=100, description="WebSocket path"),
    ]
    
    @field_validator("host")
    @classmethod
    def validate_host(cls, v: str) -> str:
        """Validate hostname format."""
        v = v.strip().lower()
        if not HOSTNAME_PATTERN.match(v) and v != "localhost":
            raise ValueError("Invalid hostname or IP address format")
        return v
    
    @field_validator("base_path", "ws_path")
    @classmethod
    def validate_path(cls, v: str) -> str:
        """Ensure path starts with /."""
        v = v.strip()
        if not v.startswith("/"):
            v = "/" + v
        return v


class RobotStatus(BaseModel):
    id: str = Field(..., description="Robot identifier")
    status_message: Optional[str] = Field(
        None,
        max_length=500,
        description="Current status description",
    )
    battery: Optional[int] = Field(
        None,
        ge=0,
        le=100,
        description="Battery percentage (0-100)",
    )
    floor: Optional[int] = Field(
        None,
        ge=-10,
        le=200,
        description="Current floor number",
    )
    zone: Optional[str] = Field(
        None,
        max_length=20,
        description="Current zone code",
    )
    is_online: bool = Field(default=True, description="Robot connectivity status")
    last_seen: Optional[datetime] = Field(None, description="Last communication timestamp")


class CommandRequest(BaseModel):
    direction: Literal["forward", "backward", "left", "right", "stop", "up", "down"] = Field(
        ...,
        description="Movement direction command",
    )
    speed: Optional[float] = Field(
        default=1.0,
        ge=0.0,
        le=1.0,
        description="Movement speed (0.0-1.0)",
    )
    duration_ms: Optional[int] = Field(
        default=None,
        ge=0,
        le=10000,
        description="Command duration in milliseconds",
    )
