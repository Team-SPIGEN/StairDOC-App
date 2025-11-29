from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class RobotEndpoint(BaseModel):
    id: str
    name: str
    host: str
    port: int = 8000
    base_path: str = "/api/v1"
    ws_path: str = "/ws/status"


class RobotStatus(BaseModel):
    id: str
    status_message: Optional[str] = None
    battery: Optional[int] = None
    floor: Optional[int] = None
    last_seen: Optional[datetime] = None


class CommandRequest(BaseModel):
    direction: str
