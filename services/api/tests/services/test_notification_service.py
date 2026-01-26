"""
Unit tests for NotificationService.

Tests:
- WebSocket connection management
- Notification creation and delivery
- User notification queries
- Notification management (read, dismiss)
- Preferences management
- Push token management
- Event handlers
"""

import pytest
import asyncio
from datetime import datetime
from unittest.mock import MagicMock, AsyncMock, patch
from collections import defaultdict

from app.services.notification_service import NotificationService
from app.schemas.notification import (
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


@pytest.fixture
def notification_service():
    """Create a fresh NotificationService instance."""
    return NotificationService()


class TestNotificationServiceInit:
    """Tests for NotificationService initialization."""
    
    def test_init_default_values(self, notification_service):
        """Test service initializes with empty state."""
        assert notification_service._notifications == {}
        assert notification_service._preferences == {}
        assert len(notification_service._connections) == 0


class TestWebSocketConnection:
    """Tests for WebSocket connection management."""
    
    @pytest.mark.asyncio
    async def test_connect(self, notification_service):
        """Test connecting a WebSocket."""
        mock_ws = AsyncMock()
        
        await notification_service.connect("user_001", mock_ws)
        
        assert mock_ws in notification_service._connections["user_001"]
        mock_ws.accept.assert_called_once()
    
    def test_disconnect(self, notification_service):
        """Test disconnecting a WebSocket."""
        mock_ws = MagicMock()
        notification_service._connections["user_001"].append(mock_ws)
        
        notification_service.disconnect("user_001", mock_ws)
        
        assert mock_ws not in notification_service._connections["user_001"]
    
    def test_disconnect_removes_empty_user(self, notification_service):
        """Test disconnecting removes user entry when empty."""
        mock_ws = MagicMock()
        notification_service._connections["user_001"].append(mock_ws)
        
        notification_service.disconnect("user_001", mock_ws)
        
        assert "user_001" not in notification_service._connections
    
    def test_disconnect_not_found(self, notification_service):
        """Test disconnecting non-existent WebSocket is safe."""
        mock_ws = MagicMock()
        
        # Should not raise
        notification_service.disconnect("user_001", mock_ws)
    
    @pytest.mark.asyncio
    async def test_send_to_user(self, notification_service):
        """Test sending data to user's WebSockets."""
        mock_ws1 = AsyncMock()
        mock_ws2 = AsyncMock()
        notification_service._connections["user_001"] = [mock_ws1, mock_ws2]
        
        count = await notification_service._send_to_user("user_001", {"msg": "test"})
        
        assert count == 2
        mock_ws1.send_json.assert_called_once_with({"msg": "test"})
        mock_ws2.send_json.assert_called_once_with({"msg": "test"})
    
    @pytest.mark.asyncio
    async def test_send_to_user_removes_dead_connections(self, notification_service):
        """Test send removes failed connections."""
        mock_ws1 = AsyncMock()
        mock_ws2 = AsyncMock()
        mock_ws2.send_json.side_effect = Exception("Connection closed")
        notification_service._connections["user_001"] = [mock_ws1, mock_ws2]
        
        count = await notification_service._send_to_user("user_001", {"msg": "test"})
        
        assert count == 1
        assert mock_ws2 not in notification_service._connections["user_001"]
    
    @pytest.mark.asyncio
    async def test_send_to_user_no_connections(self, notification_service):
        """Test sending to user with no connections."""
        count = await notification_service._send_to_user("user_001", {"msg": "test"})
        
        assert count == 0


class TestNotificationCreation:
    """Tests for notification creation and delivery."""
    
    @pytest.mark.asyncio
    async def test_create_notification(self, notification_service):
        """Test creating a notification."""
        data = NotificationCreate(
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Test Title",
            body="Test Body",
            channels=[NotificationChannel.WEBSOCKET],
        )
        
        notification = await notification_service.create_notification(data)
        
        assert notification.user_id == "user_001"
        assert notification.title == "Test Title"
        assert notification.id in notification_service._notifications
    
    @pytest.mark.asyncio
    async def test_create_notification_stores_in_memory(self, notification_service):
        """Test notification is stored in memory."""
        data = NotificationCreate(
            user_id="user_001",
            type=NotificationType.DELIVERY_COMPLETED,
            title="Delivered",
            body="Your package arrived",
            channels=[],
        )
        
        notification = await notification_service.create_notification(data)
        
        stored = notification_service._notifications.get(notification.id)
        assert stored == notification
    
    @pytest.mark.asyncio
    async def test_create_notification_respects_disabled_prefs(self, notification_service):
        """Test notification respects disabled preferences."""
        # Disable notifications for user
        notification_service._preferences["user_001"] = NotificationPreferences(
            user_id="user_001",
            enabled=False,
        )
        
        mock_ws = AsyncMock()
        notification_service._connections["user_001"].append(mock_ws)
        
        data = NotificationCreate(
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Test",
            body="Test",
            channels=[NotificationChannel.WEBSOCKET],
        )
        
        notification = await notification_service.create_notification(data)
        
        # Notification created but not delivered
        assert notification is not None
        mock_ws.send_json.assert_not_called()
    
    @pytest.mark.asyncio
    async def test_create_notification_respects_muted_types(self, notification_service):
        """Test notification respects muted types."""
        notification_service._preferences["user_001"] = NotificationPreferences(
            user_id="user_001",
            muted_types=[NotificationType.DELIVERY_STARTED],
        )
        
        mock_ws = AsyncMock()
        notification_service._connections["user_001"].append(mock_ws)
        
        data = NotificationCreate(
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Test",
            body="Test",
            channels=[NotificationChannel.WEBSOCKET],
        )
        
        notification = await notification_service.create_notification(data)
        
        # Notification created but not delivered
        assert notification is not None
        mock_ws.send_json.assert_not_called()
    
    @pytest.mark.asyncio
    async def test_deliver_websocket(self, notification_service):
        """Test WebSocket delivery."""
        mock_ws = AsyncMock()
        notification_service._connections["user_001"] = [mock_ws]
        
        notification = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Test",
            body="Test body",
        )
        
        result = await notification_service._deliver_websocket(notification)
        
        assert result is True
        mock_ws.send_json.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_deliver_push_no_tokens(self, notification_service):
        """Test push delivery with no tokens."""
        notification = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Test",
            body="Test body",
        )
        
        result = await notification_service._deliver_push(notification)
        
        assert result is False
    
    @pytest.mark.asyncio
    async def test_deliver_push_with_tokens(self, notification_service):
        """Test push delivery with tokens."""
        notification_service._push_tokens["user_001"] = [
            PushToken(
                user_id="user_001",
                token="token123",
                platform="android",
            )
        ]
        
        notification = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Test",
            body="Test body",
        )
        
        result = await notification_service._deliver_push(notification)
        
        assert result is True


class TestConvenienceMethods:
    """Tests for convenience notification methods."""
    
    @pytest.mark.asyncio
    async def test_notify_delivery_started(self, notification_service):
        """Test delivery started notification."""
        notification = await notification_service.notify_delivery_started(
            user_id="user_001",
            delivery_id="del_001",
            destination="Office 301",
        )
        
        assert notification.type == NotificationType.DELIVERY_STARTED
        assert "Office 301" in notification.body
    
    @pytest.mark.asyncio
    async def test_notify_delivery_completed(self, notification_service):
        """Test delivery completed notification."""
        notification = await notification_service.notify_delivery_completed(
            user_id="user_001",
            delivery_id="del_001",
            destination="Office 301",
        )
        
        assert notification.type == NotificationType.DELIVERY_COMPLETED
        assert notification.priority == NotificationPriority.HIGH
    
    @pytest.mark.asyncio
    async def test_notify_container_unlocked(self, notification_service):
        """Test container unlocked notification."""
        notification = await notification_service.notify_container_unlocked(
            user_id="user_001",
            robot_id="robot_001",
            unlocked_by="John Doe",
        )
        
        assert notification.type == NotificationType.CONTAINER_UNLOCKED
        assert "John Doe" in notification.body
    
    @pytest.mark.asyncio
    async def test_notify_low_battery(self, notification_service):
        """Test low battery notification."""
        notification = await notification_service.notify_low_battery(
            user_id="user_001",
            robot_id="robot_001",
            battery_level=15,
        )
        
        assert notification.type == NotificationType.ROBOT_LOW_BATTERY
        assert "15%" in notification.body
        assert notification.priority == NotificationPriority.HIGH
    
    @pytest.mark.asyncio
    async def test_notify_emergency_stop(self, notification_service):
        """Test emergency stop notification."""
        notification = await notification_service.notify_emergency_stop(
            user_id="user_001",
            robot_id="robot_001",
            reason="Obstacle detected",
        )
        
        assert notification.type == NotificationType.EMERGENCY_STOP
        assert notification.priority == NotificationPriority.URGENT
        assert "Obstacle detected" in notification.body
    
    @pytest.mark.asyncio
    async def test_notify_robot_arrived(self, notification_service):
        """Test robot arrived notification."""
        notification = await notification_service.notify_robot_arrived(
            user_id="user_001",
            robot_id="robot_001",
            location="Floor 3, Zone A",
        )
        
        assert notification.type == NotificationType.ROBOT_ARRIVED
        assert "Floor 3, Zone A" in notification.body


class TestNotificationManagement:
    """Tests for notification management."""
    
    def test_get_notification(self, notification_service):
        """Test getting a notification by ID."""
        notification = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Test",
            body="Test",
        )
        notification_service._notifications["notif_001"] = notification
        
        result = notification_service.get_notification("notif_001")
        
        assert result == notification
    
    def test_get_notification_not_found(self, notification_service):
        """Test getting non-existent notification."""
        result = notification_service.get_notification("unknown")
        
        assert result is None
    
    def test_get_user_notifications(self, notification_service):
        """Test getting notifications for a user."""
        notif1 = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Test 1",
            body="Test 1",
        )
        notif2 = Notification(
            id="notif_002",
            user_id="user_001",
            type=NotificationType.DELIVERY_COMPLETED,
            title="Test 2",
            body="Test 2",
        )
        notif3 = Notification(
            id="notif_003",
            user_id="user_002",
            type=NotificationType.DELIVERY_STARTED,
            title="Test 3",
            body="Test 3",
        )
        notification_service._notifications = {
            "notif_001": notif1,
            "notif_002": notif2,
            "notif_003": notif3,
        }
        
        response = notification_service.get_user_notifications("user_001")
        
        assert response.total == 2
        assert all(n.user_id == "user_001" for n in response.notifications)
    
    def test_get_user_notifications_unread_only(self, notification_service):
        """Test getting only unread notifications."""
        notif1 = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Read",
            body="Read",
            read_at=datetime.utcnow(),
        )
        notif2 = Notification(
            id="notif_002",
            user_id="user_001",
            type=NotificationType.DELIVERY_COMPLETED,
            title="Unread",
            body="Unread",
        )
        notification_service._notifications = {
            "notif_001": notif1,
            "notif_002": notif2,
        }
        
        response = notification_service.get_user_notifications("user_001", unread_only=True)
        
        assert response.total == 1
        assert response.notifications[0].title == "Unread"
    
    def test_get_user_notifications_filter_by_type(self, notification_service):
        """Test filtering notifications by type."""
        notif1 = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Started",
            body="Started",
        )
        notif2 = Notification(
            id="notif_002",
            user_id="user_001",
            type=NotificationType.DELIVERY_COMPLETED,
            title="Completed",
            body="Completed",
        )
        notification_service._notifications = {
            "notif_001": notif1,
            "notif_002": notif2,
        }
        
        response = notification_service.get_user_notifications(
            "user_001",
            types=[NotificationType.DELIVERY_STARTED],
        )
        
        assert response.total == 1
        assert response.notifications[0].type == NotificationType.DELIVERY_STARTED
    
    def test_mark_as_read(self, notification_service):
        """Test marking notification as read."""
        notification = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Test",
            body="Test",
        )
        notification_service._notifications["notif_001"] = notification
        
        result = notification_service.mark_as_read("notif_001", "user_001")
        
        assert result is not None
        assert result.read_at is not None
    
    def test_mark_as_read_wrong_user(self, notification_service):
        """Test marking notification as read by wrong user."""
        notification = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Test",
            body="Test",
        )
        notification_service._notifications["notif_001"] = notification
        
        result = notification_service.mark_as_read("notif_001", "user_002")
        
        assert result is None
    
    def test_mark_all_as_read(self, notification_service):
        """Test marking all notifications as read."""
        notif1 = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Test 1",
            body="Test 1",
        )
        notif2 = Notification(
            id="notif_002",
            user_id="user_001",
            type=NotificationType.DELIVERY_COMPLETED,
            title="Test 2",
            body="Test 2",
        )
        notification_service._notifications = {
            "notif_001": notif1,
            "notif_002": notif2,
        }
        
        count = notification_service.mark_all_as_read("user_001")
        
        assert count == 2
        assert notif1.read_at is not None
        assert notif2.read_at is not None
    
    def test_dismiss_notification(self, notification_service):
        """Test dismissing notification."""
        notification = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Test",
            body="Test",
        )
        notification_service._notifications["notif_001"] = notification
        
        result = notification_service.dismiss_notification("notif_001", "user_001")
        
        assert result is not None
        assert result.dismissed_at is not None
    
    def test_dismiss_notification_wrong_user(self, notification_service):
        """Test dismissing notification by wrong user."""
        notification = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Test",
            body="Test",
        )
        notification_service._notifications["notif_001"] = notification
        
        result = notification_service.dismiss_notification("notif_001", "user_002")
        
        assert result is None
    
    def test_get_unread_count(self, notification_service):
        """Test getting unread count."""
        notif1 = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Read",
            body="Read",
            read_at=datetime.utcnow(),
        )
        notif2 = Notification(
            id="notif_002",
            user_id="user_001",
            type=NotificationType.DELIVERY_COMPLETED,
            title="Unread",
            body="Unread",
        )
        notification_service._notifications = {
            "notif_001": notif1,
            "notif_002": notif2,
        }
        
        count = notification_service.get_unread_count("user_001")
        
        assert count == 1
    
    def test_get_stats(self, notification_service):
        """Test getting notification statistics."""
        notif1 = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Test 1",
            body="Test 1",
            priority=NotificationPriority.NORMAL,
        )
        notif2 = Notification(
            id="notif_002",
            user_id="user_001",
            type=NotificationType.DELIVERY_COMPLETED,
            title="Test 2",
            body="Test 2",
            priority=NotificationPriority.HIGH,
        )
        notification_service._notifications = {
            "notif_001": notif1,
            "notif_002": notif2,
        }
        
        stats = notification_service.get_stats("user_001")
        
        assert stats.total == 2
        assert stats.unread == 2
        assert len(stats.by_type) == 2
        assert len(stats.by_priority) == 2


class TestPreferencesManagement:
    """Tests for notification preferences."""
    
    def test_get_preferences_creates_default(self, notification_service):
        """Test getting preferences creates default if not exists."""
        prefs = notification_service.get_preferences("user_001")
        
        assert prefs.user_id == "user_001"
        assert "user_001" in notification_service._preferences
    
    def test_get_preferences_existing(self, notification_service):
        """Test getting existing preferences."""
        existing = NotificationPreferences(
            user_id="user_001",
            enabled=False,
        )
        notification_service._preferences["user_001"] = existing
        
        prefs = notification_service.get_preferences("user_001")
        
        assert prefs.enabled is False
    
    def test_update_preferences(self, notification_service):
        """Test updating preferences."""
        notification_service._preferences["user_001"] = NotificationPreferences(
            user_id="user_001",
        )
        
        prefs = notification_service.update_preferences("user_001", {
            "enabled": False,
            "sound_enabled": False,
        })
        
        assert prefs.enabled is False
        assert prefs.sound_enabled is False
    
    def test_update_preferences_ignores_invalid(self, notification_service):
        """Test updating preferences ignores invalid keys."""
        notification_service._preferences["user_001"] = NotificationPreferences(
            user_id="user_001",
        )
        
        prefs = notification_service.update_preferences("user_001", {
            "invalid_key": "value",
            "enabled": False,
        })
        
        assert prefs.enabled is False


class TestPushTokenManagement:
    """Tests for push token management."""
    
    def test_register_push_token(self, notification_service):
        """Test registering a push token."""
        token = notification_service.register_push_token(
            user_id="user_001",
            token="fcm_token_123",
            platform="android",
            device_id="device_001",
        )
        
        assert token.user_id == "user_001"
        assert token.token == "fcm_token_123"
        assert len(notification_service._push_tokens["user_001"]) == 1
    
    def test_register_push_token_replaces_same_device(self, notification_service):
        """Test registering replaces token for same device."""
        notification_service.register_push_token(
            user_id="user_001",
            token="old_token",
            platform="android",
            device_id="device_001",
        )
        
        notification_service.register_push_token(
            user_id="user_001",
            token="new_token",
            platform="android",
            device_id="device_001",
        )
        
        tokens = notification_service._push_tokens["user_001"]
        assert len(tokens) == 1
        assert tokens[0].token == "new_token"
    
    def test_unregister_push_token(self, notification_service):
        """Test unregistering a push token."""
        notification_service._push_tokens["user_001"] = [
            PushToken(user_id="user_001", token="token_123", platform="android")
        ]
        
        result = notification_service.unregister_push_token("user_001", "token_123")
        
        assert result is True
        assert len(notification_service._push_tokens["user_001"]) == 0
    
    def test_unregister_push_token_not_found(self, notification_service):
        """Test unregistering non-existent token."""
        result = notification_service.unregister_push_token("user_001", "unknown")
        
        assert result is False


class TestEventHandlers:
    """Tests for event handler registration."""
    
    def test_on_notification_decorator(self, notification_service):
        """Test on_notification decorator registers handler."""
        @notification_service.on_notification(NotificationType.DELIVERY_STARTED)
        def handler(notification):
            pass
        
        handlers = notification_service._handlers[NotificationType.DELIVERY_STARTED]
        assert handler in handlers
    
    @pytest.mark.asyncio
    async def test_trigger_handlers_sync(self, notification_service):
        """Test triggering synchronous handlers."""
        called = []
        
        @notification_service.on_notification(NotificationType.DELIVERY_STARTED)
        def handler(notification):
            called.append(notification.id)
        
        notification = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.DELIVERY_STARTED,
            title="Test",
            body="Test",
        )
        
        await notification_service._trigger_handlers(notification)
        
        assert "notif_001" in called
    
    @pytest.mark.asyncio
    async def test_trigger_handlers_async(self, notification_service):
        """Test triggering async handlers."""
        called = []
        
        @notification_service.on_notification(NotificationType.DELIVERY_COMPLETED)
        async def handler(notification):
            called.append(notification.id)
        
        notification = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.DELIVERY_COMPLETED,
            title="Test",
            body="Test",
        )
        
        await notification_service._trigger_handlers(notification)
        
        assert "notif_001" in called
    
    @pytest.mark.asyncio
    async def test_trigger_handlers_error_handling(self, notification_service):
        """Test handlers errors are caught."""
        @notification_service.on_notification(NotificationType.EMERGENCY_STOP)
        def bad_handler(notification):
            raise Exception("Handler error")
        
        notification = Notification(
            id="notif_001",
            user_id="user_001",
            type=NotificationType.EMERGENCY_STOP,
            title="Test",
            body="Test",
        )
        
        # Should not raise
        await notification_service._trigger_handlers(notification)
