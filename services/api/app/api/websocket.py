"""WebSocket endpoints for real-time telemetry streaming.

Provides bidirectional WebSocket communication for:
- Real-time robot telemetry broadcast
- Client subscription management
- Command acknowledgment
"""

import json
import logging
from typing import Optional

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect

from ..schemas.telemetry import TelemetryCommand, TelemetrySubscription
from ..services.telemetry_service import telemetry_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ws", tags=["websocket"])


@router.websocket("/telemetry")
async def telemetry_websocket(
    websocket: WebSocket,
    robot_id: Optional[str] = Query(default=None, description="Filter by robot ID"),
    include_sensors: bool = Query(default=False, description="Include sensor data"),
    include_system: bool = Query(default=False, description="Include system health"),
):
    """WebSocket endpoint for real-time telemetry streaming.
    
    Connect to receive continuous telemetry updates from robots.
    Supports subscription preferences via query parameters or commands.
    
    Query Parameters:
        robot_id: Filter telemetry to specific robot (optional)
        include_sensors: Include detailed sensor readings (default: false)
        include_system: Include system health metrics (default: false)
    
    Commands (send as JSON):
        - {"type": "subscribe", "payload": {"robot_id": "xxx", ...}}
        - {"type": "unsubscribe", "payload": {}}
        - {"type": "ping", "payload": {}}
    
    Example client connection:
        ws://host/api/v1/ws/telemetry?robot_id=robot-001&include_sensors=true
    """
    await websocket.accept()
    
    # Initial subscription from query params
    subscription = {
        "robot_id": robot_id,
        "include_sensors": include_sensors,
        "include_system": include_system,
    }
    
    await telemetry_service.connect(websocket, subscription)
    
    # Start mock telemetry if not already running
    await telemetry_service.start_mock_telemetry()
    
    try:
        while True:
            # Wait for client messages (commands)
            try:
                message = await websocket.receive_text()
                data = json.loads(message)
                
                command = TelemetryCommand(**data)
                await _handle_command(websocket, command)
                
            except json.JSONDecodeError:
                await websocket.send_json({
                    "type": "error",
                    "message": "Invalid JSON format",
                })
            except Exception as e:
                logger.warning(f"Error processing WebSocket message: {e}")
                await websocket.send_json({
                    "type": "error", 
                    "message": str(e),
                })
                
    except WebSocketDisconnect:
        logger.info("WebSocket client disconnected")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        await telemetry_service.disconnect(websocket)


async def _handle_command(websocket: WebSocket, command: TelemetryCommand):
    """Handle incoming WebSocket commands."""
    
    if command.type == "ping":
        await websocket.send_json({"type": "pong", "timestamp": str(__import__("datetime").datetime.utcnow())})
    
    elif command.type == "subscribe":
        if command.payload:
            try:
                sub = TelemetrySubscription(**command.payload)
                telemetry_service.update_subscription(websocket, sub.model_dump())
                await websocket.send_json({
                    "type": "subscribed",
                    "payload": sub.model_dump(),
                })
            except Exception as e:
                await websocket.send_json({
                    "type": "error",
                    "message": f"Invalid subscription: {e}",
                })
        else:
            await websocket.send_json({
                "type": "error",
                "message": "Subscribe command requires payload",
            })
    
    elif command.type == "unsubscribe":
        telemetry_service.update_subscription(websocket, {})
        await websocket.send_json({"type": "unsubscribed"})
    
    else:
        await websocket.send_json({
            "type": "error",
            "message": f"Unknown command type: {command.type}",
        })


@router.websocket("/telemetry/{robot_id}")
async def robot_telemetry_websocket(
    websocket: WebSocket,
    robot_id: str,
    include_sensors: bool = Query(default=False),
    include_system: bool = Query(default=False),
):
    """WebSocket endpoint for single robot telemetry.
    
    Convenience endpoint that automatically filters to specific robot.
    """
    await websocket.accept()
    
    subscription = {
        "robot_id": robot_id,
        "include_sensors": include_sensors,
        "include_system": include_system,
    }
    
    await telemetry_service.connect(websocket, subscription)
    await telemetry_service.start_mock_telemetry(robot_id)
    
    try:
        while True:
            message = await websocket.receive_text()
            try:
                data = json.loads(message)
                command = TelemetryCommand(**data)
                await _handle_command(websocket, command)
            except Exception as e:
                await websocket.send_json({"type": "error", "message": str(e)})
                
    except WebSocketDisconnect:
        pass
    finally:
        await telemetry_service.disconnect(websocket)
