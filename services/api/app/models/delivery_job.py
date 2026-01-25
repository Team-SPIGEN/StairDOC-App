"""Delivery Job model with optimized indexes for high-throughput queries."""

from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class DeliveryJob(SQLModel, table=True):
    """Delivery job with indexes for status, robot, and timestamp queries."""
    __tablename__ = "delivery_jobs"

    id: str = Field(default=None, primary_key=True)
    title: str
    pickup_zone: str = Field(index=True)  # Index for zone-based queries
    dropoff_zone: str = Field(index=True)
    requested_by: str = Field(index=True)  # Index for user's delivery history
    status: str = Field(default="pending", index=True)  # Index for status filtering
    assigned_robot_id: Optional[str] = Field(default=None, index=True)  # Index for robot's jobs
    created_at: datetime = Field(default_factory=datetime.utcnow, index=True)  # Index for sorting
    updated_at: datetime = Field(default_factory=datetime.utcnow)
