"""
Access Log model for tracking container lock/unlock events.

This model stores all access control actions performed on the robot's
document container, including who performed the action, when, where,
and whether it succeeded or failed.
"""

from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class AccessLog(SQLModel, table=True):
    """
    Database model for access log entries.
    
    Attributes:
        id: Auto-generated primary key
        user_id: Foreign key to the user who performed the action
        user_name: Denormalized user name for display (avoids joins)
        action: Type of action - 'lock' or 'unlock'
        location: Human-readable location description (e.g., 'Floor 2 - Office 201')
        floor: Numeric floor level (1-indexed)
        zone: Zone identifier within the floor
        timestamp: When the action occurred (UTC)
        status: Outcome - 'success', 'failed', or 'denied'
        error_message: Description of failure if status != 'success'
        photo_url: Optional URL to snapshot taken during unlock
        method: How the action was triggered - 'app', 'rfid', 'voice', 'auto'
    """
    __tablename__ = "access_logs"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: str = Field(index=True)
    user_name: str = Field(default="Unknown")
    action: str = Field(index=True)  # 'lock' or 'unlock'
    location: str = Field(default="Unknown")
    floor: Optional[int] = Field(default=None)
    zone: Optional[str] = Field(default=None)
    timestamp: datetime = Field(default_factory=datetime.utcnow, index=True)
    status: str = Field(default="success")  # 'success', 'failed', 'denied'
    error_message: Optional[str] = Field(default=None)
    photo_url: Optional[str] = Field(default=None)
    method: str = Field(default="app")  # 'app', 'rfid', 'voice', 'auto'

    class Config:
        from_attributes = True
