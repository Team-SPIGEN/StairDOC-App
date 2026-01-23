"""Telemetry schemas for real-time robot data.

These schemas define the structure of telemetry data broadcast
over WebSocket connections to connected mobile clients.
"""

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class RobotState(str, Enum):
    """Operational state of the robot."""
    
    idle = "idle"
    moving = "moving"
    climbing = "climbing"
    descending = "descending"
    delivering = "delivering"
    returning = "returning"
    charging = "charging"
    error = "error"
    maintenance = "maintenance"


class ContainerState(str, Enum):
    """State of the document container."""
    
    locked = "locked"
    unlocked = "unlocked"
    opening = "opening"
    closing = "closing"


class ConnectivityStatus(str, Enum):
    """Network connectivity status."""
    
    online = "online"
    offline = "offline"
    degraded = "degraded"


class BatteryStatus(BaseModel):
    """Battery status information."""
    
    percentage: int = Field(..., ge=0, le=100, description="Battery level 0-100%")
    is_charging: bool = Field(default=False, description="Whether currently charging")
    voltage: Optional[float] = Field(default=None, description="Battery voltage in volts")
    current: Optional[float] = Field(default=None, description="Current draw in amps")
    temperature: Optional[float] = Field(default=None, description="Battery temperature in Celsius")
    estimated_runtime_minutes: Optional[int] = Field(
        default=None, description="Estimated runtime remaining"
    )


class LocationData(BaseModel):
    """Robot location information."""
    
    floor: int = Field(..., ge=1, le=20, description="Current floor number")
    zone: Optional[str] = Field(default=None, description="Zone identifier (e.g., 'A', 'B')")
    room: Optional[str] = Field(default=None, description="Room identifier if known")
    x: Optional[float] = Field(default=None, description="X coordinate in meters")
    y: Optional[float] = Field(default=None, description="Y coordinate in meters")
    heading: Optional[float] = Field(
        default=None, ge=0, lt=360, description="Heading in degrees (0-359)"
    )


class MotionData(BaseModel):
    """Robot motion information."""
    
    linear_velocity: float = Field(default=0.0, description="Linear velocity in m/s")
    angular_velocity: float = Field(default=0.0, description="Angular velocity in rad/s")
    is_moving: bool = Field(default=False, description="Whether robot is in motion")
    target_floor: Optional[int] = Field(default=None, description="Target floor if navigating")
    target_zone: Optional[str] = Field(default=None, description="Target zone if navigating")


class SensorData(BaseModel):
    """Environmental sensor readings."""
    
    front_distance: Optional[float] = Field(
        default=None, description="Front obstacle distance in cm"
    )
    rear_distance: Optional[float] = Field(
        default=None, description="Rear obstacle distance in cm"
    )
    left_distance: Optional[float] = Field(
        default=None, description="Left obstacle distance in cm"
    )
    right_distance: Optional[float] = Field(
        default=None, description="Right obstacle distance in cm"
    )
    cliff_detected: bool = Field(default=False, description="Cliff/stairs detected ahead")
    stair_detected: bool = Field(default=False, description="Staircase detected")
    ambient_temperature: Optional[float] = Field(
        default=None, description="Ambient temperature in Celsius"
    )
    humidity: Optional[float] = Field(default=None, description="Humidity percentage")


class SystemHealth(BaseModel):
    """System health metrics."""
    
    cpu_usage: Optional[float] = Field(default=None, ge=0, le=100, description="CPU usage %")
    memory_usage: Optional[float] = Field(default=None, ge=0, le=100, description="Memory usage %")
    disk_usage: Optional[float] = Field(default=None, ge=0, le=100, description="Disk usage %")
    wifi_signal: Optional[int] = Field(
        default=None, ge=-100, le=0, description="WiFi signal strength in dBm"
    )
    uptime_seconds: Optional[int] = Field(default=None, description="System uptime in seconds")


class TelemetryData(BaseModel):
    """Complete telemetry packet from robot.
    
    This is the main schema for real-time telemetry data broadcast
    over WebSocket to mobile clients.
    """
    
    robot_id: str = Field(..., description="Unique robot identifier")
    timestamp: datetime = Field(
        default_factory=datetime.utcnow, description="Telemetry timestamp"
    )
    state: RobotState = Field(default=RobotState.idle, description="Current robot state")
    battery: BatteryStatus
    location: LocationData
    motion: MotionData
    container_state: ContainerState = Field(
        default=ContainerState.locked, description="Container lock state"
    )
    connectivity: ConnectivityStatus = Field(
        default=ConnectivityStatus.online, description="Network status"
    )
    sensors: Optional[SensorData] = Field(default=None, description="Sensor readings")
    system: Optional[SystemHealth] = Field(default=None, description="System health")
    active_delivery_id: Optional[int] = Field(
        default=None, description="Current delivery job ID if any"
    )
    error_code: Optional[str] = Field(default=None, description="Active error code if any")
    error_message: Optional[str] = Field(default=None, description="Error description")

    class Config:
        json_encoders = {datetime: lambda v: v.isoformat()}


class TelemetrySubscription(BaseModel):
    """Client subscription preferences for telemetry."""
    
    robot_id: Optional[str] = Field(
        default=None, description="Subscribe to specific robot, null for all"
    )
    include_sensors: bool = Field(default=False, description="Include sensor data")
    include_system: bool = Field(default=False, description="Include system health")
    interval_ms: int = Field(
        default=1000, ge=100, le=10000, description="Update interval in milliseconds"
    )


class TelemetryCommand(BaseModel):
    """Commands that can be sent over WebSocket."""
    
    type: str = Field(..., description="Command type: subscribe, unsubscribe, ping")
    payload: Optional[dict] = Field(default=None, description="Command payload")
