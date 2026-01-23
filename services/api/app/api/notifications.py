"""Notification API endpoints."""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException, Query
from pydantic import BaseModel

from ..schemas.notification import (
    Notification,
    NotificationCreate,
    NotificationListResponse,
    NotificationPreferences,
    NotificationPreferencesUpdate,
    NotificationStats,
    NotificationType,
    PushToken,
    PushTokenRegister,
)
from ..services.notification_service import notification_service


router = APIRouter(prefix="/notifications", tags=["notifications"])


# =============================================================================
# WebSocket Endpoint for Real-Time Notifications
# =============================================================================

@router.websocket("/ws/{user_id}")
async def notification_websocket(websocket: WebSocket, user_id: str):
    """
    WebSocket endpoint for real-time notifications.

    Delivers notifications to connected clients in <2 seconds.
    Clients should reconnect on disconnect with exponential backoff.
    """
    await notification_service.connect(user_id, websocket)
    try:
        # Keep connection alive and listen for client messages
        while True:
            data = await websocket.receive_json()

            # Handle client commands
            command = data.get("command")

            if command == "mark_read":
                notification_id = data.get("notification_id")
                if notification_id:
                    notification_service.mark_as_read(notification_id, user_id)
                    await websocket.send_json({
                        "type": "ack",
                        "command": "mark_read",
                        "notification_id": notification_id,
                    })

            elif command == "mark_all_read":
                count = notification_service.mark_all_as_read(user_id)
                await websocket.send_json({
                    "type": "ack",
                    "command": "mark_all_read",
                    "count": count,
                })

            elif command == "dismiss":
                notification_id = data.get("notification_id")
                if notification_id:
                    notification_service.dismiss_notification(notification_id, user_id)
                    await websocket.send_json({
                        "type": "ack",
                        "command": "dismiss",
                        "notification_id": notification_id,
                    })

            elif command == "ping":
                await websocket.send_json({"type": "pong"})

    except WebSocketDisconnect:
        notification_service.disconnect(user_id, websocket)


# =============================================================================
# REST Endpoints
# =============================================================================

@router.get("", response_model=NotificationListResponse)
async def list_notifications(
    user_id: str = Query(..., description="User ID to fetch notifications for"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    unread_only: bool = Query(False, description="Only return unread notifications"),
    types: list[NotificationType] | None = Query(None, description="Filter by notification types"),
):
    """Get notifications for a user with pagination and filters."""
    return notification_service.get_user_notifications(
        user_id=user_id,
        page=page,
        page_size=page_size,
        unread_only=unread_only,
        types=types,
    )


@router.get("/unread-count")
async def get_unread_count(
    user_id: str = Query(..., description="User ID"),
) -> dict[str, int]:
    """Get unread notification count for a user."""
    count = notification_service.get_unread_count(user_id)
    return {"unread_count": count}


@router.get("/stats", response_model=NotificationStats)
async def get_notification_stats(
    user_id: str = Query(..., description="User ID"),
):
    """Get notification statistics for a user."""
    return notification_service.get_stats(user_id)


@router.get("/{notification_id}", response_model=Notification)
async def get_notification(notification_id: str):
    """Get a specific notification by ID."""
    notification = notification_service.get_notification(notification_id)
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    return notification


@router.post("/{notification_id}/read", response_model=Notification)
async def mark_notification_read(
    notification_id: str,
    user_id: str = Query(..., description="User ID"),
):
    """Mark a notification as read."""
    notification = notification_service.mark_as_read(notification_id, user_id)
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    return notification


@router.post("/read-all")
async def mark_all_notifications_read(
    user_id: str = Query(..., description="User ID"),
) -> dict[str, int]:
    """Mark all notifications as read for a user."""
    count = notification_service.mark_all_as_read(user_id)
    return {"marked_count": count}


@router.post("/{notification_id}/dismiss", response_model=Notification)
async def dismiss_notification(
    notification_id: str,
    user_id: str = Query(..., description="User ID"),
):
    """Dismiss a notification."""
    notification = notification_service.dismiss_notification(notification_id, user_id)
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    return notification


# =============================================================================
# Preferences Endpoints
# =============================================================================

@router.get("/preferences/{user_id}", response_model=NotificationPreferences)
async def get_preferences(user_id: str):
    """Get notification preferences for a user."""
    return notification_service.get_preferences(user_id)


@router.patch("/preferences/{user_id}", response_model=NotificationPreferences)
async def update_preferences(user_id: str, updates: NotificationPreferencesUpdate):
    """Update notification preferences for a user."""
    return notification_service.update_preferences(
        user_id, updates.model_dump(exclude_unset=True)
    )


# =============================================================================
# Push Token Endpoints
# =============================================================================

@router.post("/push-token", response_model=PushToken)
async def register_push_token(data: PushTokenRegister):
    """Register a push notification token for a user."""
    return notification_service.register_push_token(
        user_id=data.user_id,
        token=data.token,
        platform=data.platform,
        device_id=data.device_id,
    )


@router.delete("/push-token")
async def unregister_push_token(
    user_id: str = Query(..., description="User ID"),
    token: str = Query(..., description="Push token to unregister"),
) -> dict[str, bool]:
    """Unregister a push notification token."""
    success = notification_service.unregister_push_token(user_id, token)
    return {"success": success}


# =============================================================================
# Test/Admin Endpoints
# =============================================================================

class TestNotificationRequest(BaseModel):
    """Request body for sending a test notification."""
    user_id: str
    title: str = "Test Notification"
    body: str = "This is a test notification."
    type: NotificationType = NotificationType.SYSTEM_INFO


@router.post("/test", response_model=Notification)
async def send_test_notification(data: TestNotificationRequest):
    """Send a test notification (for development/testing)."""
    return await notification_service.create_notification(
        NotificationCreate(
            user_id=data.user_id,
            type=data.type,
            title=data.title,
            body=data.body,
        )
    )
