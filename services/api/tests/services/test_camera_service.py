"""
Unit tests for CameraService.

Tests:
- Camera registration
- Settings management
- Stream management
- Frame handling
- Snapshot capture
- WebSocket viewers
- Statistics
"""

import pytest
import asyncio
from datetime import datetime
from unittest.mock import MagicMock, AsyncMock, patch

from app.services.camera_service import CameraService, QUALITY_PRESETS
from app.schemas.camera import (
    CameraInfo,
    CameraSettings,
    CameraStatus,
    StreamFormat,
    StreamQuality,
    StreamSession,
    Snapshot,
    CameraStats,
    CameraEvent,
)


@pytest.fixture
def camera_service():
    """Create a fresh CameraService instance."""
    return CameraService()


class TestCameraServiceInit:
    """Tests for CameraService initialization."""
    
    def test_init_default_values(self, camera_service):
        """Test service initializes with empty state."""
        assert camera_service._cameras == {}
        assert camera_service._settings == {}
        assert camera_service._sessions == {}
        assert camera_service._stats == {}
        assert camera_service._snapshots == {}
        assert camera_service._frame_buffers == {}


class TestCameraRegistration:
    """Tests for camera registration."""
    
    def test_register_camera(self, camera_service):
        """Test registering a camera."""
        camera = camera_service.register_camera(
            camera_id="cam_001",
            robot_id="robot_001",
            name="Test Camera"
        )
        
        assert camera.id == "cam_001"
        assert camera.robot_id == "robot_001"
        assert camera.name == "Test Camera"
        assert camera.status == CameraStatus.OFFLINE
    
    def test_register_camera_creates_settings(self, camera_service):
        """Test registering a camera creates default settings."""
        camera_service.register_camera("cam_001", "robot_001")
        
        assert "cam_001" in camera_service._settings
        assert isinstance(camera_service._settings["cam_001"], CameraSettings)
    
    def test_register_camera_creates_stats(self, camera_service):
        """Test registering a camera creates stats."""
        camera_service.register_camera("cam_001", "robot_001")
        
        assert "cam_001" in camera_service._stats
        assert camera_service._stats["cam_001"].camera_id == "cam_001"
    
    def test_get_camera(self, camera_service):
        """Test getting a registered camera."""
        camera_service.register_camera("cam_001", "robot_001")
        
        camera = camera_service.get_camera("cam_001")
        
        assert camera is not None
        assert camera.id == "cam_001"
    
    def test_get_camera_not_found(self, camera_service):
        """Test getting a non-existent camera."""
        camera = camera_service.get_camera("unknown")
        
        assert camera is None
    
    def test_get_cameras_for_robot(self, camera_service):
        """Test getting all cameras for a robot."""
        camera_service.register_camera("cam_001", "robot_001", "Camera 1")
        camera_service.register_camera("cam_002", "robot_001", "Camera 2")
        camera_service.register_camera("cam_003", "robot_002", "Camera 3")
        
        cameras = camera_service.get_cameras_for_robot("robot_001")
        
        assert len(cameras) == 2
        assert all(c.robot_id == "robot_001" for c in cameras)
    
    def test_get_cameras_for_robot_empty(self, camera_service):
        """Test getting cameras for robot with no cameras."""
        cameras = camera_service.get_cameras_for_robot("unknown_robot")
        
        assert cameras == []
    
    def test_update_camera_status(self, camera_service):
        """Test updating camera status."""
        camera_service.register_camera("cam_001", "robot_001")
        
        camera = camera_service.update_camera_status("cam_001", CameraStatus.STREAMING)
        
        assert camera.status == CameraStatus.STREAMING
        assert camera.last_frame_at is not None
    
    def test_update_camera_status_not_found(self, camera_service):
        """Test updating status for non-existent camera."""
        result = camera_service.update_camera_status("unknown", CameraStatus.ONLINE)
        
        assert result is None


class TestSettingsManagement:
    """Tests for camera settings management."""
    
    def test_get_settings_existing(self, camera_service):
        """Test getting settings for registered camera."""
        camera_service.register_camera("cam_001", "robot_001")
        
        settings = camera_service.get_settings("cam_001")
        
        assert isinstance(settings, CameraSettings)
    
    def test_get_settings_creates_default(self, camera_service):
        """Test getting settings creates default if not exists."""
        # Don't register camera
        settings = camera_service.get_settings("cam_new")
        
        assert isinstance(settings, CameraSettings)
        assert "cam_new" in camera_service._settings
    
    def test_update_settings(self, camera_service):
        """Test updating camera settings."""
        camera_service.register_camera("cam_001", "robot_001")
        
        settings = camera_service.update_settings("cam_001", {
            "quality": StreamQuality.HIGH,
            "night_vision": True,
        })
        
        assert settings.quality == StreamQuality.HIGH
        assert settings.night_vision is True
    
    def test_update_settings_ignores_invalid(self, camera_service):
        """Test updating settings ignores invalid keys."""
        camera_service.register_camera("cam_001", "robot_001")
        
        settings = camera_service.update_settings("cam_001", {
            "invalid_key": "value",
            "quality": StreamQuality.LOW,
        })
        
        assert settings.quality == StreamQuality.LOW
        # Should not have invalid_key


class TestStreamManagement:
    """Tests for stream session management."""
    
    def test_start_stream(self, camera_service):
        """Test starting a stream session."""
        camera_service.register_camera("cam_001", "robot_001")
        
        session = camera_service.start_stream(
            robot_id="robot_001",
            camera_id="cam_001",
            quality=StreamQuality.MEDIUM,
        )
        
        assert session.robot_id == "robot_001"
        assert session.camera_id == "cam_001"
        assert session.quality == StreamQuality.MEDIUM
        assert session.stream_url is not None
    
    def test_start_stream_auto_camera(self, camera_service):
        """Test starting stream auto-selects camera."""
        camera_service.register_camera("cam_001", "robot_001")
        
        session = camera_service.start_stream(robot_id="robot_001")
        
        assert session.camera_id == "cam_001"
    
    def test_start_stream_auto_registers_camera(self, camera_service):
        """Test starting stream auto-registers camera if none exist."""
        session = camera_service.start_stream(robot_id="robot_001")
        
        assert session.camera_id is not None
        assert session.camera_id in camera_service._cameras
    
    def test_start_stream_updates_camera_status(self, camera_service):
        """Test starting stream updates camera status."""
        camera_service.register_camera("cam_001", "robot_001")
        
        camera_service.start_stream(robot_id="robot_001", camera_id="cam_001")
        
        camera = camera_service.get_camera("cam_001")
        assert camera.status == CameraStatus.STREAMING
    
    def test_stop_stream(self, camera_service):
        """Test stopping a stream session."""
        camera_service.register_camera("cam_001", "robot_001")
        session = camera_service.start_stream(robot_id="robot_001", camera_id="cam_001")
        
        result = camera_service.stop_stream(session.session_id)
        
        assert result is True
        assert session.session_id not in camera_service._sessions
    
    def test_stop_stream_updates_status(self, camera_service):
        """Test stopping stream updates camera status to online."""
        camera_service.register_camera("cam_001", "robot_001")
        session = camera_service.start_stream(robot_id="robot_001", camera_id="cam_001")
        
        camera_service.stop_stream(session.session_id)
        
        camera = camera_service.get_camera("cam_001")
        assert camera.status == CameraStatus.ONLINE
    
    def test_stop_stream_not_found(self, camera_service):
        """Test stopping non-existent stream."""
        result = camera_service.stop_stream("unknown_session")
        
        assert result is False
    
    def test_get_session(self, camera_service):
        """Test getting a stream session."""
        camera_service.register_camera("cam_001", "robot_001")
        session = camera_service.start_stream(robot_id="robot_001", camera_id="cam_001")
        
        retrieved = camera_service.get_session(session.session_id)
        
        assert retrieved == session
    
    def test_get_session_not_found(self, camera_service):
        """Test getting non-existent session."""
        result = camera_service.get_session("unknown")
        
        assert result is None


class TestFrameHandling:
    """Tests for frame handling."""
    
    def test_update_frame(self, camera_service):
        """Test updating frame buffer."""
        camera_service.register_camera("cam_001", "robot_001")
        frame_data = b"fake_jpeg_data"
        
        camera_service.update_frame("cam_001", frame_data)
        
        assert camera_service._frame_buffers["cam_001"] == frame_data
    
    def test_update_frame_increments_stats(self, camera_service):
        """Test updating frame increments stats."""
        camera_service.register_camera("cam_001", "robot_001")
        
        camera_service.update_frame("cam_001", b"frame1")
        camera_service.update_frame("cam_001", b"frame2")
        
        stats = camera_service._stats["cam_001"]
        assert stats.total_frames == 2
    
    def test_update_frame_updates_timestamp(self, camera_service):
        """Test updating frame updates camera timestamp."""
        camera_service.register_camera("cam_001", "robot_001")
        
        camera_service.update_frame("cam_001", b"frame_data")
        
        camera = camera_service.get_camera("cam_001")
        assert camera.last_frame_at is not None
    
    def test_get_latest_frame(self, camera_service):
        """Test getting latest frame."""
        camera_service.register_camera("cam_001", "robot_001")
        camera_service.update_frame("cam_001", b"latest_frame")
        
        frame = camera_service.get_latest_frame("cam_001")
        
        assert frame == b"latest_frame"
    
    def test_get_latest_frame_not_found(self, camera_service):
        """Test getting latest frame when none exists."""
        frame = camera_service.get_latest_frame("unknown")
        
        assert frame is None
    
    def test_generate_placeholder_frame(self, camera_service):
        """Test generating placeholder JPEG frame."""
        preset = QUALITY_PRESETS[StreamQuality.MEDIUM]
        
        frame = camera_service._generate_placeholder_frame("cam_001", preset)
        
        # Should be valid JPEG (starts with FFD8)
        assert frame[:2] == b'\xff\xd8'
        # Should end with FFD9
        assert frame[-2:] == b'\xff\xd9'


class TestSnapshotCapture:
    """Tests for snapshot capture."""
    
    @pytest.mark.asyncio
    async def test_capture_snapshot(self, camera_service):
        """Test capturing a snapshot."""
        camera_service.register_camera("cam_001", "robot_001")
        
        snapshot = await camera_service.capture_snapshot(
            robot_id="robot_001",
            camera_id="cam_001",
        )
        
        assert snapshot.camera_id == "cam_001"
        assert snapshot.robot_id == "robot_001"
        assert snapshot.id in camera_service._snapshots
    
    @pytest.mark.asyncio
    async def test_capture_snapshot_auto_camera(self, camera_service):
        """Test capturing snapshot auto-selects camera."""
        camera_service.register_camera("cam_001", "robot_001")
        
        snapshot = await camera_service.capture_snapshot(robot_id="robot_001")
        
        assert snapshot.camera_id == "cam_001"
    
    @pytest.mark.asyncio
    async def test_capture_snapshot_auto_registers_camera(self, camera_service):
        """Test capturing snapshot auto-registers camera."""
        snapshot = await camera_service.capture_snapshot(robot_id="robot_001")
        
        assert snapshot.camera_id is not None
    
    @pytest.mark.asyncio
    async def test_capture_snapshot_stores_data(self, camera_service):
        """Test capturing snapshot stores image data."""
        camera_service.register_camera("cam_001", "robot_001")
        
        snapshot = await camera_service.capture_snapshot(
            robot_id="robot_001",
            camera_id="cam_001",
        )
        
        # Should have stored frame data
        data = camera_service.get_snapshot_data(snapshot.id)
        assert data is not None
    
    @pytest.mark.asyncio
    async def test_capture_snapshot_with_metadata(self, camera_service):
        """Test capturing snapshot with metadata."""
        camera_service.register_camera("cam_001", "robot_001")
        
        snapshot = await camera_service.capture_snapshot(
            robot_id="robot_001",
            camera_id="cam_001",
            include_metadata=True,
        )
        
        assert snapshot.metadata is not None
        assert "quality" in snapshot.metadata
    
    @pytest.mark.asyncio
    async def test_capture_snapshot_without_metadata(self, camera_service):
        """Test capturing snapshot without metadata."""
        camera_service.register_camera("cam_001", "robot_001")
        
        snapshot = await camera_service.capture_snapshot(
            robot_id="robot_001",
            camera_id="cam_001",
            include_metadata=False,
        )
        
        assert snapshot.metadata is None
    
    def test_get_snapshot(self, camera_service):
        """Test getting snapshot metadata."""
        # Manually add a snapshot
        snapshot = Snapshot(
            id="snap_001",
            camera_id="cam_001",
            robot_id="robot_001",
            image_url="/test",
            width=640,
            height=480,
            file_size=1000,
        )
        camera_service._snapshots["snap_001"] = snapshot
        
        result = camera_service.get_snapshot("snap_001")
        
        assert result == snapshot
    
    def test_get_snapshot_not_found(self, camera_service):
        """Test getting non-existent snapshot."""
        result = camera_service.get_snapshot("unknown")
        
        assert result is None
    
    def test_get_snapshot_data(self, camera_service):
        """Test getting snapshot image data."""
        camera_service._frame_buffers["snapshot_snap_001"] = b"image_data"
        
        data = camera_service.get_snapshot_data("snap_001")
        
        assert data == b"image_data"
    
    def test_get_snapshot_data_not_found(self, camera_service):
        """Test getting non-existent snapshot data."""
        data = camera_service.get_snapshot_data("unknown")
        
        assert data is None
    
    def test_get_snapshots_for_robot(self, camera_service):
        """Test getting snapshots for a robot."""
        snap1 = Snapshot(
            id="snap_001",
            camera_id="cam_001",
            robot_id="robot_001",
            image_url="/1",
            width=640, height=480, file_size=1000,
        )
        snap2 = Snapshot(
            id="snap_002",
            camera_id="cam_001",
            robot_id="robot_001",
            image_url="/2",
            width=640, height=480, file_size=1000,
        )
        snap3 = Snapshot(
            id="snap_003",
            camera_id="cam_002",
            robot_id="robot_002",
            image_url="/3",
            width=640, height=480, file_size=1000,
        )
        camera_service._snapshots = {
            "snap_001": snap1,
            "snap_002": snap2,
            "snap_003": snap3,
        }
        
        snapshots = camera_service.get_snapshots_for_robot("robot_001")
        
        assert len(snapshots) == 2
        assert all(s.robot_id == "robot_001" for s in snapshots)


class TestWebSocketViewers:
    """Tests for WebSocket viewer management."""
    
    @pytest.mark.asyncio
    async def test_add_viewer(self, camera_service):
        """Test adding a WebSocket viewer."""
        mock_ws = AsyncMock()
        
        await camera_service.add_viewer("cam_001", mock_ws)
        
        assert mock_ws in camera_service._viewers["cam_001"]
        mock_ws.accept.assert_called_once()
    
    def test_remove_viewer(self, camera_service):
        """Test removing a WebSocket viewer."""
        mock_ws = MagicMock()
        camera_service._viewers["cam_001"].append(mock_ws)
        
        camera_service.remove_viewer("cam_001", mock_ws)
        
        assert mock_ws not in camera_service._viewers["cam_001"]
    
    def test_remove_viewer_not_found(self, camera_service):
        """Test removing non-existent viewer is safe."""
        mock_ws = MagicMock()
        
        # Should not raise
        camera_service.remove_viewer("cam_001", mock_ws)
    
    @pytest.mark.asyncio
    async def test_broadcast_frame(self, camera_service):
        """Test broadcasting frame to viewers."""
        mock_ws1 = AsyncMock()
        mock_ws2 = AsyncMock()
        camera_service._viewers["cam_001"] = [mock_ws1, mock_ws2]
        
        count = await camera_service.broadcast_frame("cam_001", b"frame_data")
        
        assert count == 2
        mock_ws1.send_bytes.assert_called_once_with(b"frame_data")
        mock_ws2.send_bytes.assert_called_once_with(b"frame_data")
    
    @pytest.mark.asyncio
    async def test_broadcast_frame_removes_dead_connections(self, camera_service):
        """Test broadcast removes failed connections."""
        mock_ws1 = AsyncMock()
        mock_ws2 = AsyncMock()
        mock_ws2.send_bytes.side_effect = Exception("Connection closed")
        camera_service._viewers["cam_001"] = [mock_ws1, mock_ws2]
        
        count = await camera_service.broadcast_frame("cam_001", b"frame_data")
        
        assert count == 1
        assert mock_ws2 not in camera_service._viewers["cam_001"]
    
    @pytest.mark.asyncio
    async def test_broadcast_frame_no_viewers(self, camera_service):
        """Test broadcasting with no viewers."""
        count = await camera_service.broadcast_frame("cam_001", b"frame_data")
        
        assert count == 0
    
    @pytest.mark.asyncio
    async def test_broadcast_event(self, camera_service):
        """Test broadcasting camera event."""
        mock_ws = AsyncMock()
        camera_service._viewers["cam_001"] = [mock_ws]
        
        event = CameraEvent(
            event="motion_detected",
            camera_id="cam_001",
            robot_id="robot_001",
        )
        
        await camera_service.broadcast_event("cam_001", event)
        
        mock_ws.send_json.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_broadcast_event_handles_errors(self, camera_service):
        """Test broadcast event handles errors gracefully."""
        mock_ws = AsyncMock()
        mock_ws.send_json.side_effect = Exception("Error")
        camera_service._viewers["cam_001"] = [mock_ws]
        
        event = CameraEvent(
            event="motion_detected",
            camera_id="cam_001",
            robot_id="robot_001",
        )
        
        # Should not raise
        await camera_service.broadcast_event("cam_001", event)


class TestStatistics:
    """Tests for camera statistics."""
    
    def test_get_stats_existing(self, camera_service):
        """Test getting stats for registered camera."""
        camera_service.register_camera("cam_001", "robot_001")
        
        stats = camera_service.get_stats("cam_001")
        
        assert stats.camera_id == "cam_001"
    
    def test_get_stats_creates_default(self, camera_service):
        """Test getting stats creates default if not exists."""
        stats = camera_service.get_stats("cam_new")
        
        assert stats.camera_id == "cam_new"
        assert "cam_new" in camera_service._stats
    
    def test_get_active_sessions(self, camera_service):
        """Test getting all active sessions."""
        camera_service.register_camera("cam_001", "robot_001")
        camera_service.register_camera("cam_002", "robot_002")
        
        camera_service.start_stream(robot_id="robot_001", camera_id="cam_001")
        camera_service.start_stream(robot_id="robot_002", camera_id="cam_002")
        
        sessions = camera_service.get_active_sessions()
        
        assert len(sessions) == 2
    
    def test_get_active_sessions_empty(self, camera_service):
        """Test getting active sessions when none exist."""
        sessions = camera_service.get_active_sessions()
        
        assert sessions == []


class TestQualityPresets:
    """Tests for quality presets."""
    
    def test_low_quality_preset(self):
        """Test low quality preset values."""
        preset = QUALITY_PRESETS[StreamQuality.LOW]
        
        assert preset["width"] == 320
        assert preset["height"] == 240
        assert preset["fps"] == 10
    
    def test_medium_quality_preset(self):
        """Test medium quality preset values."""
        preset = QUALITY_PRESETS[StreamQuality.MEDIUM]
        
        assert preset["width"] == 640
        assert preset["height"] == 480
        assert preset["fps"] == 15
    
    def test_high_quality_preset(self):
        """Test high quality preset values."""
        preset = QUALITY_PRESETS[StreamQuality.HIGH]
        
        assert preset["width"] == 1280
        assert preset["height"] == 720
        assert preset["fps"] == 25
    
    def test_auto_quality_preset(self):
        """Test auto quality defaults to medium."""
        auto = QUALITY_PRESETS[StreamQuality.AUTO]
        medium = QUALITY_PRESETS[StreamQuality.MEDIUM]
        
        assert auto == medium


class TestMJPEGStreamGeneration:
    """Tests for MJPEG stream generation."""
    
    @pytest.mark.asyncio
    async def test_generate_mjpeg_stream_no_session(self, camera_service):
        """Test stream generation with no session returns."""
        stream = camera_service.generate_mjpeg_stream("cam_001", "unknown_session")
        
        # Should return empty (async generator that yields nothing)
        frames = []
        async for frame in stream:
            frames.append(frame)
        
        assert frames == []
    
    @pytest.mark.asyncio
    async def test_generate_mjpeg_stream_format(self, camera_service):
        """Test stream generates proper MJPEG format."""
        camera_service.register_camera("cam_001", "robot_001")
        session = camera_service.start_stream(robot_id="robot_001", camera_id="cam_001")
        
        stream = camera_service.generate_mjpeg_stream("cam_001", session.session_id)
        
        # Get first frame
        frame = await stream.__anext__()
        
        # Should have MJPEG boundary
        assert b"--frame" in frame
        assert b"Content-Type: image/jpeg" in frame
        
        # Stop session to end stream
        camera_service.stop_stream(session.session_id)


class TestStreamMultipleSessions:
    """Tests for multiple stream sessions."""
    
    def test_stop_stream_with_remaining_sessions(self, camera_service):
        """Test stopping stream when other sessions exist."""
        camera_service.register_camera("cam_001", "robot_001")
        
        session1 = camera_service.start_stream(robot_id="robot_001", camera_id="cam_001")
        session2 = camera_service.start_stream(robot_id="robot_001", camera_id="cam_001")
        
        # Stop first session
        camera_service.stop_stream(session1.session_id)
        
        # Camera should still be streaming
        camera = camera_service.get_camera("cam_001")
        assert camera.status == CameraStatus.STREAMING
        
        # Stop second session
        camera_service.stop_stream(session2.session_id)
        
        # Now camera should be online
        camera = camera_service.get_camera("cam_001")
        assert camera.status == CameraStatus.ONLINE
