"""Notification schemas for real-time alerts and history."""

from datetime import datetime
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, Field


class NotificationType(str, Enum):
    """Types of notifications."""

    # Delivery events
    DELIVERY_STARTED = "delivery_started"
    DELIVERY_COMPLETED = "delivery_completed"
    DELIVERY_FAILED = "delivery_failed"
    DELIVERY_APPROACHING = "delivery_approaching"

    # Container events
    CONTAINER_UNLOCKED = "container_unlocked"
    CONTAINER_LOCKED = "container_locked"
    CONTAINER_ACCESS_DENIED = "container_access_denied"

    # Robot status
    ROBOT_LOW_BATTERY = "robot_low_battery"
    ROBOT_ERROR = "robot_error"
    ROBOT_OFFLINE = "robot_offline"
    ROBOT_ONLINE = "robot_online"

    # Navigation
    ROBOT_ARRIVED = "robot_arrived"
    ROBOT_STUCK = "robot_stuck"
    EMERGENCY_STOP = "emergency_stop"

    # System
    SYSTEM_ALERT = "system_alert"
    MAINTENANCE_REQUIRED = "maintenance_required"


class NotificationPriority(str, Enum):
    """Priority levels for notifications."""

    LOW = "low"
    NORMAL = "normal"
    HIGH = "high"
    URGENT = "urgent"


class NotificationChannel(str, Enum):
    """Delivery channels for notifications."""

    PUSH = "push"
    WEBSOCKET = "websocket"
    EMAIL = "email"
    SMS = "sms"


class NotificationBase(BaseModel):
    """Base notification data."""

    type: NotificationType
    title: str
    body: str
    priority: NotificationPriority = NotificationPriority.NORMAL
    data: dict[str, Any] = Field(default_factory=dict)


class Notification(NotificationBase):
    """Full notification with metadata."""

    id: str
    user_id: str
    robot_id: Optional[str] = None
    delivery_id: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    read_at: Optional[datetime] = None
    dismissed_at: Optional[datetime] = None
    channels: list[NotificationChannel] = Field(
        default_factory=lambda: [NotificationChannel.WEBSOCKET, NotificationChannel.PUSH]
    )

    @property
    def is_read(self) -> bool:
        return self.read_at is not None

    @property
    def is_dismissed(self) -> bool:
        return self.dismissed_at is not None


class NotificationCreate(NotificationBase):
    """Schema for creating a new notification."""

    user_id: str
    robot_id: Optional[str] = None
    delivery_id: Optional[str] = None
    channels: list[NotificationChannel] = Field(
        default_factory=lambda: [NotificationChannel.WEBSOCKET, NotificationChannel.PUSH]
    )


class NotificationUpdate(BaseModel):
    """Schema for updating a notification."""

    read_at: Optional[datetime] = None
    dismissed_at: Optional[datetime] = None


class NotificationPreferences(BaseModel):
    """User notification preferences."""

    user_id: str
    enabled: bool = True
    channels: list[NotificationChannel] = Field(
        default_factory=lambda: [NotificationChannel.WEBSOCKET, NotificationChannel.PUSH]
    )
    quiet_hours_start: Optional[str] = None  # HH:MM format
    quiet_hours_end: Optional[str] = None
    muted_types: list[NotificationType] = Field(default_factory=list)
    sound_enabled: bool = True
    vibration_enabled: bool = True


class NotificationPreferencesUpdate(BaseModel):
    """Schema for updating preferences."""

    enabled: Optional[bool] = None
    channels: Optional[list[NotificationChannel]] = None
    quiet_hours_start: Optional[str] = None
    quiet_hours_end: Optional[str] = None
    muted_types: Optional[list[NotificationType]] = None
    sound_enabled: Optional[bool] = None
    vibration_enabled: Optional[bool] = None


class NotificationListResponse(BaseModel):
    """Response for listing notifications."""

    notifications: list[Notification]
    total: int
    unread_count: int
    page: int = 1
    page_size: int = 20


class NotificationEvent(BaseModel):
    """WebSocket event for real-time notifications."""

    event: str = "notification"
    notification: Notification
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class NotificationBatchAction(BaseModel):
    """Batch action on notifications."""

    notification_ids: list[str]
    action: str  # "mark_read", "dismiss", "delete"


class NotificationStats(BaseModel):
    """Notification statistics for a user."""

    total: int
    unread: int
    by_type: dict[str, int]
    by_priority: dict[str, int]


class PushToken(BaseModel):
    """Push notification token registration."""

    user_id: str
    token: str
    platform: str  # "ios", "android", "web"
    device_id: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class PushTokenRegister(BaseModel):
    """Schema for registering a push token."""

    token: str
    platform: str
    device_id: Optional[str] = None
