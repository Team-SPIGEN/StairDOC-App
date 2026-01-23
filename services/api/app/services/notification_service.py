"""Notification service for real-time alerts and push notifications."""

import asyncio
import uuid
from collections import defaultdict
from datetime import datetime
from typing import Any, Callable

from fastapi import WebSocket

from ..schemas.notification import (
    Notification,
    NotificationChannel,
    NotificationCreate,
    NotificationEvent,
    NotificationListResponse,
    NotificationPreferences,
    NotificationPriority,
    NotificationStats,
    NotificationType,
    PushToken,
)


class NotificationService:
    """
    Service for managing notifications.

    Handles:
    - Real-time notification delivery via WebSocket
    - Notification storage and history
    - User preferences management
    - Push token registration
    - Batch operations
    """

    def __init__(self) -> None:
        """Initialize the notification service."""
        # In-memory storage (replace with database in production)
        self._notifications: dict[str, Notification] = {}
        self._preferences: dict[str, NotificationPreferences] = {}
        self._push_tokens: dict[str, list[PushToken]] = defaultdict(list)

        # WebSocket connections per user
        self._connections: dict[str, list[WebSocket]] = defaultdict(list)

        # Event handlers for notification events
        self._handlers: dict[NotificationType, list[Callable]] = defaultdict(list)

    # -------------------------------------------------------------------------
    # WebSocket Connection Management
    # -------------------------------------------------------------------------

    async def connect(self, user_id: str, websocket: WebSocket) -> None:
        """Register a WebSocket connection for a user."""
        await websocket.accept()
        self._connections[user_id].append(websocket)

    def disconnect(self, user_id: str, websocket: WebSocket) -> None:
        """Remove a WebSocket connection for a user."""
        if websocket in self._connections[user_id]:
            self._connections[user_id].remove(websocket)
        if not self._connections[user_id]:
            del self._connections[user_id]

    async def _send_to_user(self, user_id: str, data: dict[str, Any]) -> int:
        """Send data to all WebSocket connections for a user."""
        sent_count = 0
        dead_connections = []

        for ws in self._connections.get(user_id, []):
            try:
                await ws.send_json(data)
                sent_count += 1
            except Exception:
                dead_connections.append(ws)

        # Clean up dead connections
        for ws in dead_connections:
            self.disconnect(user_id, ws)

        return sent_count

    # -------------------------------------------------------------------------
    # Notification Creation and Delivery
    # -------------------------------------------------------------------------

    async def create_notification(
        self, data: NotificationCreate
    ) -> Notification:
        """Create and deliver a notification."""
        notification = Notification(
            id=str(uuid.uuid4()),
            user_id=data.user_id,
            robot_id=data.robot_id,
            delivery_id=data.delivery_id,
            type=data.type,
            title=data.title,
            body=data.body,
            priority=data.priority,
            data=data.data,
            channels=data.channels,
        )

        # Store notification
        self._notifications[notification.id] = notification

        # Check user preferences
        prefs = self._preferences.get(data.user_id)
        if prefs and not prefs.enabled:
            return notification
        if prefs and data.type in prefs.muted_types:
            return notification

        # Deliver via enabled channels
        delivery_tasks = []

        if NotificationChannel.WEBSOCKET in data.channels:
            delivery_tasks.append(self._deliver_websocket(notification))

        if NotificationChannel.PUSH in data.channels:
            delivery_tasks.append(self._deliver_push(notification))

        if delivery_tasks:
            await asyncio.gather(*delivery_tasks, return_exceptions=True)

        # Trigger event handlers
        await self._trigger_handlers(notification)

        return notification

    async def _deliver_websocket(self, notification: Notification) -> bool:
        """Deliver notification via WebSocket."""
        event = NotificationEvent(notification=notification)
        sent = await self._send_to_user(
            notification.user_id,
            event.model_dump(mode="json"),
        )
        return sent > 0

    async def _deliver_push(self, notification: Notification) -> bool:
        """Deliver notification via push (placeholder)."""
        tokens = self._push_tokens.get(notification.user_id, [])
        if not tokens:
            return False

        # TODO: Integrate with FCM, APNS, or other push service
        for token in tokens:
            print(f"[PUSH] -> {token.platform}:{token.token[:20]}... : {notification.title}")

        return True

    # -------------------------------------------------------------------------
    # Convenience Methods for Common Notifications
    # -------------------------------------------------------------------------

    async def notify_delivery_started(
        self, user_id: str, delivery_id: str, destination: str
    ) -> Notification:
        """Send notification when delivery starts."""
        return await self.create_notification(
            NotificationCreate(
                user_id=user_id,
                delivery_id=delivery_id,
                type=NotificationType.DELIVERY_STARTED,
                title="Delivery Started",
                body=f"Your delivery to {destination} has begun.",
                priority=NotificationPriority.NORMAL,
                data={"delivery_id": delivery_id, "destination": destination},
            )
        )

    async def notify_delivery_completed(
        self, user_id: str, delivery_id: str, destination: str
    ) -> Notification:
        """Send notification when delivery completes."""
        return await self.create_notification(
            NotificationCreate(
                user_id=user_id,
                delivery_id=delivery_id,
                type=NotificationType.DELIVERY_COMPLETED,
                title="Delivery Completed",
                body=f"Your delivery has arrived at {destination}.",
                priority=NotificationPriority.HIGH,
                data={"delivery_id": delivery_id, "destination": destination},
            )
        )

    async def notify_container_unlocked(
        self, user_id: str, robot_id: str, unlocked_by: str
    ) -> Notification:
        """Send notification when container is unlocked."""
        return await self.create_notification(
            NotificationCreate(
                user_id=user_id,
                robot_id=robot_id,
                type=NotificationType.CONTAINER_UNLOCKED,
                title="Container Unlocked",
                body=f"Container was unlocked by {unlocked_by}.",
                priority=NotificationPriority.NORMAL,
                data={"robot_id": robot_id, "unlocked_by": unlocked_by},
            )
        )

    async def notify_low_battery(
        self, user_id: str, robot_id: str, battery_level: int
    ) -> Notification:
        """Send notification for low battery."""
        return await self.create_notification(
            NotificationCreate(
                user_id=user_id,
                robot_id=robot_id,
                type=NotificationType.ROBOT_LOW_BATTERY,
                title="Low Battery Warning",
                body=f"Robot battery is at {battery_level}%. Please charge soon.",
                priority=NotificationPriority.HIGH,
                data={"robot_id": robot_id, "battery_level": battery_level},
            )
        )

    async def notify_emergency_stop(
        self, user_id: str, robot_id: str, reason: str = "Manual trigger"
    ) -> Notification:
        """Send notification for emergency stop."""
        return await self.create_notification(
            NotificationCreate(
                user_id=user_id,
                robot_id=robot_id,
                type=NotificationType.EMERGENCY_STOP,
                title="⚠️ Emergency Stop Activated",
                body=f"Robot has stopped. Reason: {reason}",
                priority=NotificationPriority.URGENT,
                data={"robot_id": robot_id, "reason": reason},
            )
        )

    async def notify_robot_arrived(
        self, user_id: str, robot_id: str, location: str
    ) -> Notification:
        """Send notification when robot arrives at destination."""
        return await self.create_notification(
            NotificationCreate(
                user_id=user_id,
                robot_id=robot_id,
                type=NotificationType.ROBOT_ARRIVED,
                title="Robot Arrived",
                body=f"Robot has arrived at {location}.",
                priority=NotificationPriority.HIGH,
                data={"robot_id": robot_id, "location": location},
            )
        )

    # -------------------------------------------------------------------------
    # Notification Management
    # -------------------------------------------------------------------------

    def get_notification(self, notification_id: str) -> Notification | None:
        """Get a notification by ID."""
        return self._notifications.get(notification_id)

    def get_user_notifications(
        self,
        user_id: str,
        page: int = 1,
        page_size: int = 20,
        unread_only: bool = False,
        types: list[NotificationType] | None = None,
    ) -> NotificationListResponse:
        """Get notifications for a user."""
        user_notifications = [
            n for n in self._notifications.values()
            if n.user_id == user_id and not n.is_dismissed
        ]

        if unread_only:
            user_notifications = [n for n in user_notifications if not n.is_read]

        if types:
            user_notifications = [n for n in user_notifications if n.type in types]

        # Sort by created_at descending
        user_notifications.sort(key=lambda n: n.created_at, reverse=True)

        total = len(user_notifications)
        unread = sum(1 for n in user_notifications if not n.is_read)

        # Paginate
        start = (page - 1) * page_size
        end = start + page_size
        paginated = user_notifications[start:end]

        return NotificationListResponse(
            notifications=paginated,
            total=total,
            unread_count=unread,
            page=page,
            page_size=page_size,
        )

    def mark_as_read(
        self, notification_id: str, user_id: str
    ) -> Notification | None:
        """Mark a notification as read."""
        notification = self._notifications.get(notification_id)
        if notification and notification.user_id == user_id:
            notification.read_at = datetime.utcnow()
            return notification
        return None

    def mark_all_as_read(self, user_id: str) -> int:
        """Mark all notifications as read for a user."""
        count = 0
        for notification in self._notifications.values():
            if notification.user_id == user_id and not notification.is_read:
                notification.read_at = datetime.utcnow()
                count += 1
        return count

    def dismiss_notification(
        self, notification_id: str, user_id: str
    ) -> Notification | None:
        """Dismiss a notification."""
        notification = self._notifications.get(notification_id)
        if notification and notification.user_id == user_id:
            notification.dismissed_at = datetime.utcnow()
            return notification
        return None

    def get_unread_count(self, user_id: str) -> int:
        """Get unread notification count for a user."""
        return sum(
            1 for n in self._notifications.values()
            if n.user_id == user_id and not n.is_read and not n.is_dismissed
        )

    def get_stats(self, user_id: str) -> NotificationStats:
        """Get notification statistics for a user."""
        user_notifications = [
            n for n in self._notifications.values()
            if n.user_id == user_id and not n.is_dismissed
        ]

        by_type: dict[str, int] = defaultdict(int)
        by_priority: dict[str, int] = defaultdict(int)
        unread = 0

        for n in user_notifications:
            by_type[n.type.value] += 1
            by_priority[n.priority.value] += 1
            if not n.is_read:
                unread += 1

        return NotificationStats(
            total=len(user_notifications),
            unread=unread,
            by_type=dict(by_type),
            by_priority=dict(by_priority),
        )

    # -------------------------------------------------------------------------
    # Preferences Management
    # -------------------------------------------------------------------------

    def get_preferences(self, user_id: str) -> NotificationPreferences:
        """Get notification preferences for a user."""
        if user_id not in self._preferences:
            self._preferences[user_id] = NotificationPreferences(user_id=user_id)
        return self._preferences[user_id]

    def update_preferences(
        self, user_id: str, updates: dict[str, Any]
    ) -> NotificationPreferences:
        """Update notification preferences for a user."""
        prefs = self.get_preferences(user_id)
        for key, value in updates.items():
            if hasattr(prefs, key) and value is not None:
                setattr(prefs, key, value)
        return prefs

    # -------------------------------------------------------------------------
    # Push Token Management
    # -------------------------------------------------------------------------

    def register_push_token(
        self, user_id: str, token: str, platform: str, device_id: str | None = None
    ) -> PushToken:
        """Register a push notification token."""
        push_token = PushToken(
            user_id=user_id,
            token=token,
            platform=platform,
            device_id=device_id,
        )

        # Remove existing token for same device
        self._push_tokens[user_id] = [
            t for t in self._push_tokens[user_id]
            if t.device_id != device_id or device_id is None
        ]

        self._push_tokens[user_id].append(push_token)
        return push_token

    def unregister_push_token(self, user_id: str, token: str) -> bool:
        """Unregister a push notification token."""
        original_count = len(self._push_tokens[user_id])
        self._push_tokens[user_id] = [
            t for t in self._push_tokens[user_id] if t.token != token
        ]
        return len(self._push_tokens[user_id]) < original_count

    # -------------------------------------------------------------------------
    # Event Handlers
    # -------------------------------------------------------------------------

    def on_notification(
        self, notification_type: NotificationType
    ) -> Callable:
        """Decorator to register a handler for notification events."""
        def decorator(func: Callable) -> Callable:
            self._handlers[notification_type].append(func)
            return func
        return decorator

    async def _trigger_handlers(self, notification: Notification) -> None:
        """Trigger registered handlers for a notification."""
        handlers = self._handlers.get(notification.type, [])
        for handler in handlers:
            try:
                if asyncio.iscoroutinefunction(handler):
                    await handler(notification)
                else:
                    handler(notification)
            except Exception as e:
                print(f"Error in notification handler: {e}")


# Singleton instance
notification_service = NotificationService()

