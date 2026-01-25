"""Camera schemas for live video streaming."""

from datetime import datetime
from enum import Enum
from typing import Any

from pydantic import BaseModel, Field


class CameraStatus(str, Enum):
    """Camera connection status."""
    ONLINE = "online"
    OFFLINE = "offline"
    CONNECTING = "connecting"
    ERROR = "error"
    STREAMING = "streaming"


class StreamQuality(str, Enum):
    """Video stream quality presets."""
    LOW = "low"        # 320x240, 10fps - minimal bandwidth
    MEDIUM = "medium"  # 640x480, 15fps - balanced
    HIGH = "high"      # 1280x720, 25fps - high quality
    AUTO = "auto"      # Adaptive based on network


class StreamFormat(str, Enum):
    """Supported stream formats."""
    MJPEG = "mjpeg"    # Motion JPEG - best for low latency
    WEBRTC = "webrtc"  # WebRTC - best for bidirectional
    HLS = "hls"        # HTTP Live Streaming - best for compatibility


class CameraInfo(BaseModel):
    """Information about a camera."""
    id: str = Field(..., description="Unique camera identifier")
    robot_id: str = Field(..., description="Associated robot ID")
    name: str = Field(default="Main Camera", description="Camera display name")
    status: CameraStatus = Field(default=CameraStatus.OFFLINE)
    resolution_width: int = Field(default=640, ge=160, le=1920)
    resolution_height: int = Field(default=480, ge=120, le=1080)
    fps: int = Field(default=15, ge=5, le=30)
    format: StreamFormat = Field(default=StreamFormat.MJPEG)
    last_frame_at: datetime | None = Field(default=None)
    stream_url: str | None = Field(default=None)


class CameraSettings(BaseModel):
    """Camera configuration settings."""
    quality: StreamQuality = Field(default=StreamQuality.MEDIUM)
    brightness: int = Field(default=50, ge=0, le=100)
    contrast: int = Field(default=50, ge=0, le=100)
    saturation: int = Field(default=50, ge=0, le=100)
    auto_exposure: bool = Field(default=True)
    night_vision: bool = Field(default=False)
    flip_horizontal: bool = Field(default=False)
    flip_vertical: bool = Field(default=False)
    rotation: int = Field(default=0, description="Rotation in degrees (0, 90, 180, 270)")


class CameraSettingsUpdate(BaseModel):
    """Update camera settings."""
    quality: StreamQuality | None = None
    brightness: int | None = Field(default=None, ge=0, le=100)
    contrast: int | None = Field(default=None, ge=0, le=100)
    saturation: int | None = Field(default=None, ge=0, le=100)
    auto_exposure: bool | None = None
    night_vision: bool | None = None
    flip_horizontal: bool | None = None
    flip_vertical: bool | None = None
    rotation: int | None = None


class StreamSession(BaseModel):
    """Active stream session information."""
    session_id: str
    camera_id: str
    robot_id: str
    started_at: datetime = Field(default_factory=datetime.utcnow)
    quality: StreamQuality
    format: StreamFormat
    stream_url: str
    viewers: int = Field(default=1)
    bytes_sent: int = Field(default=0)
    frames_sent: int = Field(default=0)
    avg_latency_ms: float = Field(default=0.0)


class StreamRequest(BaseModel):
    """Request to start a video stream."""
    robot_id: str
    camera_id: str | None = Field(default=None, description="Specific camera, or None for default")
    quality: StreamQuality = Field(default=StreamQuality.MEDIUM)
    format: StreamFormat = Field(default=StreamFormat.MJPEG)


class StreamResponse(BaseModel):
    """Response with stream connection details."""
    session_id: str
    stream_url: str
    format: StreamFormat
    quality: StreamQuality
    estimated_latency_ms: int = Field(default=200)
    expires_at: datetime


class Snapshot(BaseModel):
    """A captured snapshot from the camera."""
    id: str
    camera_id: str
    robot_id: str
    captured_at: datetime = Field(default_factory=datetime.utcnow)
    image_url: str
    thumbnail_url: str | None = None
    width: int
    height: int
    file_size: int = Field(description="Size in bytes")
    metadata: dict[str, Any] | None = None


class SnapshotRequest(BaseModel):
    """Request to capture a snapshot."""
    robot_id: str
    camera_id: str | None = None
    quality: StreamQuality = Field(default=StreamQuality.HIGH)
    include_metadata: bool = Field(default=True, description="Include robot position, timestamp, etc.")


class CameraEvent(BaseModel):
    """Real-time camera event for WebSocket."""
    type: str = Field(default="camera_event")
    event: str  # frame, status_change, error, snapshot
    camera_id: str
    robot_id: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    data: dict[str, Any] | None = None


class CameraStats(BaseModel):
    """Camera streaming statistics."""
    camera_id: str
    total_frames: int = 0
    dropped_frames: int = 0
    avg_fps: float = 0.0
    avg_latency_ms: float = 0.0
    min_latency_ms: float = 0.0
    max_latency_ms: float = 0.0
    bandwidth_kbps: float = 0.0
    uptime_seconds: int = 0
    last_error: str | None = None
