"""Camera service for video streaming with low latency."""

import asyncio
import io
import time
import uuid
from collections import defaultdict
from datetime import datetime, timedelta
from typing import AsyncGenerator

from fastapi import WebSocket

from ..schemas.camera import (
    CameraEvent,
    CameraInfo,
    CameraSettings,
    CameraStats,
    CameraStatus,
    Snapshot,
    StreamFormat,
    StreamQuality,
    StreamSession,
)


# Quality presets for stream configuration
QUALITY_PRESETS = {
    StreamQuality.LOW: {"width": 320, "height": 240, "fps": 10, "jpeg_quality": 60},
    StreamQuality.MEDIUM: {"width": 640, "height": 480, "fps": 15, "jpeg_quality": 75},
    StreamQuality.HIGH: {"width": 1280, "height": 720, "fps": 25, "jpeg_quality": 85},
    StreamQuality.AUTO: {"width": 640, "height": 480, "fps": 15, "jpeg_quality": 75},
}


class CameraService:
    """
    Service for managing camera streams with <500ms latency target.

    Features:
    - MJPEG streaming for low latency
    - Multiple simultaneous viewers
    - Quality adaptation
    - Snapshot capture
    - Stream statistics
    """

    def __init__(self) -> None:
        """Initialize the camera service."""
        # Camera registry: camera_id -> CameraInfo
        self._cameras: dict[str, CameraInfo] = {}

        # Camera settings: camera_id -> CameraSettings
        self._settings: dict[str, CameraSettings] = {}

        # Active stream sessions: session_id -> StreamSession
        self._sessions: dict[str, StreamSession] = {}

        # WebSocket viewers: camera_id -> list[WebSocket]
        self._viewers: dict[str, list[WebSocket]] = defaultdict(list)

        # Camera stats: camera_id -> CameraStats
        self._stats: dict[str, CameraStats] = {}

        # Snapshots: snapshot_id -> Snapshot
        self._snapshots: dict[str, Snapshot] = {}

        # Frame buffers for each camera (latest frame)
        self._frame_buffers: dict[str, bytes] = {}

        # Stream tasks
        self._stream_tasks: dict[str, asyncio.Task] = {}

    # -------------------------------------------------------------------------
    # Camera Registration
    # -------------------------------------------------------------------------

    def register_camera(
        self,
        camera_id: str,
        robot_id: str,
        name: str = "Main Camera",
    ) -> CameraInfo:
        """Register a new camera."""
        camera = CameraInfo(
            id=camera_id,
            robot_id=robot_id,
            name=name,
            status=CameraStatus.OFFLINE,
        )
        self._cameras[camera_id] = camera
        self._settings[camera_id] = CameraSettings()
        self._stats[camera_id] = CameraStats(camera_id=camera_id)
        return camera

    def get_camera(self, camera_id: str) -> CameraInfo | None:
        """Get camera information."""
        return self._cameras.get(camera_id)

    def get_cameras_for_robot(self, robot_id: str) -> list[CameraInfo]:
        """Get all cameras for a robot."""
        return [c for c in self._cameras.values() if c.robot_id == robot_id]

    def update_camera_status(
        self, camera_id: str, status: CameraStatus
    ) -> CameraInfo | None:
        """Update camera status."""
        camera = self._cameras.get(camera_id)
        if camera:
            camera.status = status
            if status == CameraStatus.STREAMING:
                camera.last_frame_at = datetime.utcnow()
        return camera

    # -------------------------------------------------------------------------
    # Settings Management
    # -------------------------------------------------------------------------

    def get_settings(self, camera_id: str) -> CameraSettings:
        """Get camera settings."""
        if camera_id not in self._settings:
            self._settings[camera_id] = CameraSettings()
        return self._settings[camera_id]

    def update_settings(
        self, camera_id: str, updates: dict
    ) -> CameraSettings:
        """Update camera settings."""
        settings = self.get_settings(camera_id)
        for key, value in updates.items():
            if hasattr(settings, key) and value is not None:
                setattr(settings, key, value)
        return settings

    # -------------------------------------------------------------------------
    # Stream Management
    # -------------------------------------------------------------------------

    def start_stream(
        self,
        robot_id: str,
        camera_id: str | None = None,
        quality: StreamQuality = StreamQuality.MEDIUM,
        stream_format: StreamFormat = StreamFormat.MJPEG,
    ) -> StreamSession:
        """Start a new stream session."""
        # Use default camera if not specified
        if camera_id is None:
            cameras = self.get_cameras_for_robot(robot_id)
            if cameras:
                camera_id = cameras[0].id
            else:
                # Auto-register a default camera
                camera_id = f"cam_{robot_id}_main"
                self.register_camera(camera_id, robot_id, "Main Camera")

        session_id = str(uuid.uuid4())
        preset = QUALITY_PRESETS[quality]

        # Build stream URL based on format
        if stream_format == StreamFormat.MJPEG:
            stream_url = f"/api/v1/camera/{camera_id}/stream/mjpeg?session={session_id}"
        else:
            stream_url = f"/api/v1/camera/{camera_id}/stream?session={session_id}"

        session = StreamSession(
            session_id=session_id,
            camera_id=camera_id,
            robot_id=robot_id,
            quality=quality,
            format=stream_format,
            stream_url=stream_url,
        )

        self._sessions[session_id] = session
        self.update_camera_status(camera_id, CameraStatus.STREAMING)

        # Update camera info
        camera = self._cameras.get(camera_id)
        if camera:
            camera.resolution_width = preset["width"]
            camera.resolution_height = preset["height"]
            camera.fps = preset["fps"]
            camera.format = stream_format
            camera.stream_url = stream_url

        return session

    def stop_stream(self, session_id: str) -> bool:
        """Stop a stream session."""
        session = self._sessions.pop(session_id, None)
        if session:
            # Check if any other sessions for this camera
            camera_sessions = [
                s for s in self._sessions.values()
                if s.camera_id == session.camera_id
            ]
            if not camera_sessions:
                self.update_camera_status(session.camera_id, CameraStatus.ONLINE)

            # Cancel stream task if exists
            task = self._stream_tasks.pop(session_id, None)
            if task:
                task.cancel()

            return True
        return False

    def get_session(self, session_id: str) -> StreamSession | None:
        """Get stream session info."""
        return self._sessions.get(session_id)

    # -------------------------------------------------------------------------
    # Frame Handling
    # -------------------------------------------------------------------------

    def update_frame(self, camera_id: str, frame_data: bytes) -> None:
        """Update the latest frame for a camera."""
        self._frame_buffers[camera_id] = frame_data

        # Update stats
        stats = self._stats.get(camera_id)
        if stats:
            stats.total_frames += 1

        # Update camera timestamp
        camera = self._cameras.get(camera_id)
        if camera:
            camera.last_frame_at = datetime.utcnow()

    def get_latest_frame(self, camera_id: str) -> bytes | None:
        """Get the latest frame for a camera."""
        return self._frame_buffers.get(camera_id)

    async def generate_mjpeg_stream(
        self,
        camera_id: str,
        session_id: str,
    ) -> AsyncGenerator[bytes, None]:
        """
        Generate MJPEG stream frames.

        This is a simulation - in production, this would receive frames
        from the actual Raspberry Pi camera via WebSocket or RTSP.
        """
        session = self._sessions.get(session_id)
        if not session:
            return

        settings = self.get_settings(camera_id)
        preset = QUALITY_PRESETS[settings.quality]
        frame_interval = 1.0 / preset["fps"]

        frame_count = 0
        start_time = time.time()

        while session_id in self._sessions:
            frame_start = time.time()

            # Get latest frame or generate placeholder
            frame_data = self.get_latest_frame(camera_id)
            if frame_data is None:
                # Generate a placeholder frame (in production, skip or show "no signal")
                frame_data = self._generate_placeholder_frame(camera_id, preset)

            # MJPEG boundary format
            yield (
                b"--frame\r\n"
                b"Content-Type: image/jpeg\r\n\r\n" +
                frame_data +
                b"\r\n"
            )

            frame_count += 1

            # Update session stats
            session.frames_sent = frame_count
            session.bytes_sent += len(frame_data)

            # Calculate and update latency
            frame_time = (time.time() - frame_start) * 1000
            session.avg_latency_ms = (
                session.avg_latency_ms * 0.9 + frame_time * 0.1
            )

            # Update camera stats
            stats = self._stats.get(camera_id)
            if stats:
                elapsed = time.time() - start_time
                if elapsed > 0:
                    stats.avg_fps = frame_count / elapsed
                stats.avg_latency_ms = session.avg_latency_ms

            # Maintain frame rate
            elapsed = time.time() - frame_start
            if elapsed < frame_interval:
                await asyncio.sleep(frame_interval - elapsed)

    def _generate_placeholder_frame(
        self, camera_id: str, preset: dict
    ) -> bytes:
        """Generate a placeholder JPEG frame."""
        # Simple placeholder - in production use actual camera frames
        # This creates a minimal valid JPEG for testing
        width = preset["width"]
        height = preset["height"]

        # Minimal placeholder (in production, use PIL or OpenCV)
        # This is a 1x1 gray JPEG as placeholder
        placeholder_jpeg = bytes([
            0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46,
            0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01,
            0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
            0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08,
            0x07, 0x07, 0x07, 0x09, 0x09, 0x08, 0x0A, 0x0C,
            0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
            0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D,
            0x1A, 0x1C, 0x1C, 0x20, 0x24, 0x2E, 0x27, 0x20,
            0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
            0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27,
            0x39, 0x3D, 0x38, 0x32, 0x3C, 0x2E, 0x33, 0x34,
            0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
            0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4,
            0x00, 0x1F, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01,
            0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04,
            0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0xFF,
            0xC4, 0x00, 0xB5, 0x10, 0x00, 0x02, 0x01, 0x03,
            0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04,
            0x00, 0x00, 0x01, 0x7D, 0x01, 0x02, 0x03, 0x00,
            0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06,
            0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32,
            0x81, 0x91, 0xA1, 0x08, 0x23, 0x42, 0xB1, 0xC1,
            0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72,
            0x82, 0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A,
            0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x34, 0x35,
            0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45,
            0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55,
            0x56, 0x57, 0x58, 0x59, 0x5A, 0x63, 0x64, 0x65,
            0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75,
            0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85,
            0x86, 0x87, 0x88, 0x89, 0x8A, 0x92, 0x93, 0x94,
            0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3,
            0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2,
            0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA,
            0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9,
            0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8,
            0xD9, 0xDA, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6,
            0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4,
            0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFF, 0xDA,
            0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
            0xFB, 0xD5, 0xDB, 0x20, 0xBA, 0xA3, 0xAE, 0xF9,
            0x59, 0xE7, 0x14, 0x00, 0xFF, 0xD9
        ])

        return placeholder_jpeg

    # -------------------------------------------------------------------------
    # Snapshot Capture
    # -------------------------------------------------------------------------

    async def capture_snapshot(
        self,
        robot_id: str,
        camera_id: str | None = None,
        quality: StreamQuality = StreamQuality.HIGH,
        include_metadata: bool = True,
    ) -> Snapshot:
        """Capture a snapshot from the camera."""
        # Use default camera if not specified
        if camera_id is None:
            cameras = self.get_cameras_for_robot(robot_id)
            if cameras:
                camera_id = cameras[0].id
            else:
                camera_id = f"cam_{robot_id}_main"
                self.register_camera(camera_id, robot_id)

        # Get latest frame or capture new one
        frame_data = self.get_latest_frame(camera_id)
        if frame_data is None:
            preset = QUALITY_PRESETS[quality]
            frame_data = self._generate_placeholder_frame(camera_id, preset)

        snapshot_id = str(uuid.uuid4())
        preset = QUALITY_PRESETS[quality]

        snapshot = Snapshot(
            id=snapshot_id,
            camera_id=camera_id,
            robot_id=robot_id,
            image_url=f"/api/v1/camera/snapshots/{snapshot_id}",
            thumbnail_url=f"/api/v1/camera/snapshots/{snapshot_id}/thumbnail",
            width=preset["width"],
            height=preset["height"],
            file_size=len(frame_data),
            metadata={"quality": quality.value} if include_metadata else None,
        )

        self._snapshots[snapshot_id] = snapshot
        # Store actual image data separately (in production, use file storage)
        self._frame_buffers[f"snapshot_{snapshot_id}"] = frame_data

        return snapshot

    def get_snapshot(self, snapshot_id: str) -> Snapshot | None:
        """Get snapshot metadata."""
        return self._snapshots.get(snapshot_id)

    def get_snapshot_data(self, snapshot_id: str) -> bytes | None:
        """Get snapshot image data."""
        return self._frame_buffers.get(f"snapshot_{snapshot_id}")

    def get_snapshots_for_robot(
        self, robot_id: str, limit: int = 20
    ) -> list[Snapshot]:
        """Get recent snapshots for a robot."""
        snapshots = [
            s for s in self._snapshots.values()
            if s.robot_id == robot_id
        ]
        snapshots.sort(key=lambda s: s.captured_at, reverse=True)
        return snapshots[:limit]

    # -------------------------------------------------------------------------
    # WebSocket Viewers
    # -------------------------------------------------------------------------

    async def add_viewer(
        self, camera_id: str, websocket: WebSocket
    ) -> None:
        """Add a WebSocket viewer for a camera."""
        await websocket.accept()
        self._viewers[camera_id].append(websocket)

    def remove_viewer(
        self, camera_id: str, websocket: WebSocket
    ) -> None:
        """Remove a WebSocket viewer."""
        if websocket in self._viewers[camera_id]:
            self._viewers[camera_id].remove(websocket)

    async def broadcast_frame(
        self, camera_id: str, frame_data: bytes
    ) -> int:
        """Broadcast a frame to all WebSocket viewers."""
        sent_count = 0
        dead_connections = []

        for ws in self._viewers.get(camera_id, []):
            try:
                await ws.send_bytes(frame_data)
                sent_count += 1
            except Exception:
                dead_connections.append(ws)

        # Clean up dead connections
        for ws in dead_connections:
            self.remove_viewer(camera_id, ws)

        return sent_count

    async def broadcast_event(
        self, camera_id: str, event: CameraEvent
    ) -> None:
        """Broadcast a camera event to all viewers."""
        for ws in self._viewers.get(camera_id, []):
            try:
                await ws.send_json(event.model_dump(mode="json"))
            except Exception:
                pass

    # -------------------------------------------------------------------------
    # Statistics
    # -------------------------------------------------------------------------

    def get_stats(self, camera_id: str) -> CameraStats:
        """Get camera streaming statistics."""
        if camera_id not in self._stats:
            self._stats[camera_id] = CameraStats(camera_id=camera_id)
        return self._stats[camera_id]

    def get_active_sessions(self) -> list[StreamSession]:
        """Get all active stream sessions."""
        return list(self._sessions.values())


# Singleton instance
camera_service = CameraService()
