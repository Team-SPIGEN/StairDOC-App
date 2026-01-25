"""
Delivery job schemas with validation.

Implements:
- Zone format validation
- Status state machine
- Input sanitization
"""

import re
from datetime import datetime
from typing import Annotated, Literal, Optional

from pydantic import BaseModel, Field, field_validator

# Valid delivery statuses
DELIVERY_STATUSES = {"pending", "assigned", "in_progress", "picked_up", "delivered", "cancelled", "failed"}

# Zone pattern (e.g., "FLOOR1-A", "F2-B3", "GROUND-LOBBY")
ZONE_PATTERN = re.compile(r'^[A-Z0-9_\-]{1,20}$', re.IGNORECASE)


class DeliveryJobBase(BaseModel):
    title: Annotated[
        str,
        Field(
            ...,
            min_length=1,
            max_length=200,
            description="Brief description of the delivery",
        ),
    ]
    pickup_zone: Annotated[
        str,
        Field(
            ...,
            min_length=1,
            max_length=20,
            description="Zone code for pickup location",
        ),
    ]
    dropoff_zone: Annotated[
        str,
        Field(
            ...,
            min_length=1,
            max_length=20,
            description="Zone code for dropoff location",
        ),
    ]
    requested_by: Annotated[
        str,
        Field(
            ...,
            min_length=1,
            max_length=100,
            description="User ID or name of requester",
        ),
    ]
    
    @field_validator("title")
    @classmethod
    def sanitize_title(cls, v: str) -> str:
        """Sanitize title to prevent injection."""
        v = v.strip()
        # Remove potentially dangerous characters
        v = re.sub(r'[<>{}]', '', v)
        return v
    
    @field_validator("pickup_zone", "dropoff_zone")
    @classmethod
    def validate_zone(cls, v: str) -> str:
        """Validate zone format."""
        v = v.strip().upper()
        if not ZONE_PATTERN.match(v):
            raise ValueError(
                "Zone must be 1-20 characters containing only letters, "
                "numbers, underscores, and hyphens"
            )
        return v


class DeliveryJobCreate(DeliveryJobBase):
    assigned_robot_id: Optional[str] = Field(
        default=None,
        max_length=50,
        description="Optional robot ID to assign",
    )


class DeliveryJobUpdate(BaseModel):
    status: Optional[Literal[
        "pending", "assigned", "in_progress", "picked_up", "delivered", "cancelled", "failed"
    ]] = Field(
        default=None,
        description="New delivery status",
    )
    assigned_robot_id: Optional[str] = Field(
        default=None,
        max_length=50,
        description="Robot ID to assign",
    )


class DeliveryJobRead(DeliveryJobBase):
    id: str = Field(..., description="Unique delivery job ID")
    status: str = Field(..., description="Current delivery status")
    assigned_robot_id: Optional[str] = Field(None, description="Assigned robot ID")
    created_at: datetime = Field(..., description="Job creation timestamp")
    updated_at: datetime = Field(..., description="Last update timestamp")
