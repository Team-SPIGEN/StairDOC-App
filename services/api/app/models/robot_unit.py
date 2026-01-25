"""Robot Unit model with optimized indexes for status and location queries."""

from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class RobotUnit(SQLModel, table=True):
    """Robot unit with indexes for name, status, and location queries."""
    __tablename__ = "robot_units"

    id: str = Field(default=None, primary_key=True)
    name: str = Field(index=True)  # Index for name lookup
    host: str
    port: int = Field(default=8000)
    ws_path: str = Field(default="/ws/status")
    base_path: str = Field(default="/api/v1")
    status_message: Optional[str] = None
    battery: Optional[int] = None
    floor: Optional[int] = Field(default=None, index=True)  # Index for floor filtering
    last_seen: datetime = Field(default_factory=datetime.utcnow, index=True)  # Index for activity sorting
