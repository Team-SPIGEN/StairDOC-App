"""User model with optimized indexes for authentication and role queries."""

from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class User(SQLModel, table=True):
    """User with indexes for email, role, and activity queries."""
    __tablename__ = "users"

    id: str = Field(default=None, primary_key=True)
    email: str = Field(index=True, unique=True)  # Unique index for auth lookup
    full_name: Optional[str] = None
    role: str = Field(default="operator", index=True)  # Index for role-based queries
    hashed_password: str
    is_active: bool = Field(default=True, index=True)  # Index for active user filtering
    created_at: datetime = Field(default_factory=datetime.utcnow, nullable=False, index=True)
