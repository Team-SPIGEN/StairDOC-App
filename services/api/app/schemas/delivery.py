from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class DeliveryJobBase(BaseModel):
    title: str
    pickup_zone: str
    dropoff_zone: str
    requested_by: str


class DeliveryJobCreate(DeliveryJobBase):
    assigned_robot_id: Optional[str] = None


class DeliveryJobUpdate(BaseModel):
    status: Optional[str] = None
    assigned_robot_id: Optional[str] = None


class DeliveryJobRead(DeliveryJobBase):
    id: str
    status: str
    assigned_robot_id: Optional[str]
    created_at: datetime
    updated_at: datetime
