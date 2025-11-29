from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class RobotUnit(SQLModel, table=True):
    __tablename__ = "robot_units"

    id: str = Field(default=None, primary_key=True)
    name: str
    host: str
    port: int = Field(default=8000)
    ws_path: str = Field(default="/ws/status")
    base_path: str = Field(default="/api/v1")
    status_message: Optional[str] = None
    battery: Optional[int] = None
    floor: Optional[int] = None
    last_seen: datetime = Field(default_factory=datetime.utcnow)
