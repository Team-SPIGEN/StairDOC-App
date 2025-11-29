from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class DeliveryJob(SQLModel, table=True):
    __tablename__ = "delivery_jobs"

    id: str = Field(default=None, primary_key=True)
    title: str
    pickup_zone: str
    dropoff_zone: str
    requested_by: str
    status: str = Field(default="pending")
    assigned_robot_id: Optional[str] = Field(default=None, foreign_key="robot_units.id")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
