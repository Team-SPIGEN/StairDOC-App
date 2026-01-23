"""Telemetry service for managing robot telemetry state and broadcasting.

This service:
- Maintains current telemetry state for all robots
- Manages WebSocket connections
- Broadcasts telemetry updates to subscribed clients
- Generates mock telemetry for development/testing
"""

import asyncio
import logging
import random
from datetime import datetime
from typing import Dict, Optional, Set

from fastapi import WebSocket

from ..schemas.telemetry import (
    BatteryStatus,
    ConnectivityStatus,
    ContainerState,
    LocationData,
    MotionData,
    RobotState,
    SensorData,
    SystemHealth,
    TelemetryData,
)

logger = logging.getLogger(__name__)


class TelemetryService:
    """Service for managing robot telemetry and WebSocket broadcasts."""

    def __init__(self):
        # Current telemetry state per robot
        self._telemetry: Dict[str, TelemetryData] = {}
        
        # Active WebSocket connections
        self._connections: Set[WebSocket] = set()
        
        # Subscription preferences per connection
        self._subscriptions: Dict[WebSocket, dict] = {}
        
        # Mock mode flag
        self._mock_mode = True
        
        # Background task for mock data generation
        self._mock_task: Optional[asyncio.Task] = None

    async def start_mock_telemetry(self, robot_id: str = "robot-001"):
        """Start generating mock telemetry data for development."""
        if self._mock_task is not None:
            return
        
        self._mock_mode = True
        self._mock_task = asyncio.create_task(self._generate_mock_telemetry(robot_id))
        logger.info(f"Started mock telemetry generation for {robot_id}")

    async def stop_mock_telemetry(self):
        """Stop mock telemetry generation."""
        if self._mock_task:
            self._mock_task.cancel()
            try:
                await self._mock_task
            except asyncio.CancelledError:
                pass
            self._mock_task = None
            logger.info("Stopped mock telemetry generation")

    async def _generate_mock_telemetry(self, robot_id: str):
        """Generate mock telemetry data at regular intervals."""
        # Initial state
        battery_level = 85
        floor = 1
        x, y = 0.0, 0.0
        heading = 0.0
        is_moving = False
        state = RobotState.idle
        container_locked = True
        
        states = [RobotState.idle, RobotState.moving, RobotState.delivering]
        
        while True:
            try:
                # Simulate battery drain
                if is_moving:
                    battery_level = max(0, battery_level - random.uniform(0.01, 0.05))
                
                # Randomly change state
                if random.random() < 0.1:
                    state = random.choice(states)
                    is_moving = state in [RobotState.moving, RobotState.delivering]
                
                # Simulate movement
                if is_moving:
                    heading = (heading + random.uniform(-10, 10)) % 360
                    x += random.uniform(-0.5, 0.5)
                    y += random.uniform(-0.5, 0.5)
                    
                    # Occasionally change floors
                    if random.random() < 0.02:
                        floor = max(1, min(5, floor + random.choice([-1, 1])))
                
                # Simulate container lock/unlock
                if random.random() < 0.02:
                    container_locked = not container_locked
                
                telemetry = TelemetryData(
                    robot_id=robot_id,
                    timestamp=datetime.utcnow(),
                    state=state,
                    battery=BatteryStatus(
                        percentage=int(battery_level),
                        is_charging=battery_level < 20 and not is_moving,
                        voltage=round(11.5 + (battery_level / 100) * 1.2, 2),
                        temperature=round(25 + random.uniform(-2, 5), 1),
                        estimated_runtime_minutes=int(battery_level * 2.5),
                    ),
                    location=LocationData(
                        floor=floor,
                        zone=random.choice(["A", "B", "C"]),
                        x=round(x, 2),
                        y=round(y, 2),
                        heading=round(heading, 1),
                    ),
                    motion=MotionData(
                        linear_velocity=round(random.uniform(0.2, 0.8), 2) if is_moving else 0.0,
                        angular_velocity=round(random.uniform(-0.3, 0.3), 2) if is_moving else 0.0,
                        is_moving=is_moving,
                        target_floor=floor + 1 if is_moving and random.random() < 0.3 else None,
                    ),
                    container_state=ContainerState.locked if container_locked else ContainerState.unlocked,
                    connectivity=ConnectivityStatus.online,
                    sensors=SensorData(
                        front_distance=round(random.uniform(30, 200), 1),
                        rear_distance=round(random.uniform(30, 200), 1),
                        left_distance=round(random.uniform(20, 150), 1),
                        right_distance=round(random.uniform(20, 150), 1),
                        cliff_detected=False,
                        stair_detected=random.random() < 0.05,
                        ambient_temperature=round(22 + random.uniform(-2, 3), 1),
                        humidity=round(45 + random.uniform(-10, 15), 1),
                    ),
                    system=SystemHealth(
                        cpu_usage=round(random.uniform(15, 45), 1),
                        memory_usage=round(random.uniform(30, 60), 1),
                        disk_usage=round(random.uniform(20, 40), 1),
                        wifi_signal=random.randint(-70, -40),
                        uptime_seconds=random.randint(3600, 86400),
                    ),
                )
                
                await self.update_telemetry(telemetry)
                await asyncio.sleep(1)  # 1 second interval
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Error generating mock telemetry: {e}")
                await asyncio.sleep(5)

    async def update_telemetry(self, telemetry: TelemetryData):
        """Update telemetry for a robot and broadcast to subscribers."""
        self._telemetry[telemetry.robot_id] = telemetry
        await self._broadcast(telemetry)

    def get_telemetry(self, robot_id: str) -> Optional[TelemetryData]:
        """Get current telemetry for a specific robot."""
        return self._telemetry.get(robot_id)

    def get_all_telemetry(self) -> Dict[str, TelemetryData]:
        """Get telemetry for all robots."""
        return dict(self._telemetry)

    async def connect(self, websocket: WebSocket, subscription: Optional[dict] = None):
        """Register a WebSocket connection."""
        self._connections.add(websocket)
        self._subscriptions[websocket] = subscription or {}
        logger.info(f"WebSocket connected, total connections: {len(self._connections)}")
        
        # Send current state immediately
        for robot_id, telemetry in self._telemetry.items():
            if self._should_send(websocket, telemetry):
                try:
                    await websocket.send_json(telemetry.model_dump(mode="json"))
                except Exception:
                    pass

    async def disconnect(self, websocket: WebSocket):
        """Unregister a WebSocket connection."""
        self._connections.discard(websocket)
        self._subscriptions.pop(websocket, None)
        logger.info(f"WebSocket disconnected, total connections: {len(self._connections)}")

    def update_subscription(self, websocket: WebSocket, subscription: dict):
        """Update subscription preferences for a connection."""
        if websocket in self._subscriptions:
            self._subscriptions[websocket] = subscription

    def _should_send(self, websocket: WebSocket, telemetry: TelemetryData) -> bool:
        """Check if telemetry should be sent to this connection based on subscription."""
        sub = self._subscriptions.get(websocket, {})
        robot_filter = sub.get("robot_id")
        
        if robot_filter and robot_filter != telemetry.robot_id:
            return False
        
        return True

    async def _broadcast(self, telemetry: TelemetryData):
        """Broadcast telemetry to all subscribed connections."""
        if not self._connections:
            return
        
        # Prepare payload based on subscription preferences
        disconnected = []
        
        for ws in self._connections:
            if not self._should_send(ws, telemetry):
                continue
            
            try:
                sub = self._subscriptions.get(ws, {})
                data = telemetry.model_dump(mode="json")
                
                # Remove optional data if not subscribed
                if not sub.get("include_sensors", False):
                    data.pop("sensors", None)
                if not sub.get("include_system", False):
                    data.pop("system", None)
                
                await ws.send_json(data)
            except Exception as e:
                logger.warning(f"Failed to send telemetry to client: {e}")
                disconnected.append(ws)
        
        # Clean up disconnected clients
        for ws in disconnected:
            self._connections.discard(ws)
            self._subscriptions.pop(ws, None)


# Global singleton instance
telemetry_service = TelemetryService()
