"""Camera API endpoints for live video streaming."""

from datetime import datetime, timedelta

from fastapi import APIRouter, HTTPException, Query, WebSocket, WebSocketDisconnect
from fastapi.responses import Response, StreamingResponse

from ..schemas.camera import (
    CameraInfo,
    CameraSettings,
    CameraSettingsUpdate,
    CameraStats,
    Snapshot,
    SnapshotRequest,
    StreamFormat,
    StreamQuality,
    StreamRequest,
    StreamResponse,
    StreamSession,
)
from ..services.camera_service import camera_service


router = APIRouter(prefix="/camera", tags=["camera"])


# =============================================================================
# Camera Information
# =============================================================================

@router.get("/robot/{robot_id}", response_model=list[CameraInfo])
async def get_cameras_for_robot(robot_id: str):
    """Get all cameras associated with a robot."""
    cameras = camera_service.get_cameras_for_robot(robot_id)
    if not cameras:
        # Auto-register default camera
        camera = camera_service.register_camera(
            f"cam_{robot_id}_main",
            robot_id,
            "Main Camera",
        )
        cameras = [camera]
    return cameras


@router.get("/{camera_id}", response_model=CameraInfo)
async def get_camera(camera_id: str):
    """Get camera information."""
    camera = camera_service.get_camera(camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")
    return camera


# =============================================================================
# Camera Settings
# =============================================================================

@router.get("/{camera_id}/settings", response_model=CameraSettings)
async def get_camera_settings(camera_id: str):
    """Get camera settings."""
    return camera_service.get_settings(camera_id)


@router.patch("/{camera_id}/settings", response_model=CameraSettings)
async def update_camera_settings(
    camera_id: str,
    updates: CameraSettingsUpdate,
):
    """Update camera settings."""
    return camera_service.update_settings(
        camera_id,
        updates.model_dump(exclude_unset=True),
    )


# =============================================================================
# Stream Management
# =============================================================================

@router.post("/stream/start", response_model=StreamResponse)
async def start_stream(request: StreamRequest):
    """
    Start a new video stream session.

    Returns connection details for the stream.
    For MJPEG, use the stream_url with an <img> tag or fetch.
    """
    session = camera_service.start_stream(
        robot_id=request.robot_id,
        camera_id=request.camera_id,
        quality=request.quality,
        stream_format=request.format,
    )

    return StreamResponse(
        session_id=session.session_id,
        stream_url=session.stream_url,
        format=session.format,
        quality=session.quality,
        estimated_latency_ms=200 if session.format == StreamFormat.MJPEG else 500,
        expires_at=datetime.utcnow() + timedelta(hours=1),
    )


@router.post("/stream/{session_id}/stop")
async def stop_stream(session_id: str) -> dict[str, bool]:
    """Stop a video stream session."""
    success = camera_service.stop_stream(session_id)
    if not success:
        raise HTTPException(status_code=404, detail="Session not found")
    return {"stopped": True}


@router.get("/stream/{session_id}", response_model=StreamSession)
async def get_stream_session(session_id: str):
    """Get stream session information."""
    session = camera_service.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return session


@router.get("/streams/active", response_model=list[StreamSession])
async def get_active_streams():
    """Get all active stream sessions."""
    return camera_service.get_active_sessions()


# =============================================================================
# MJPEG Stream Endpoint
# =============================================================================

@router.get("/{camera_id}/stream/mjpeg")
async def mjpeg_stream(
    camera_id: str,
    session: str = Query(..., description="Session ID from start_stream"),
    quality: StreamQuality = Query(StreamQuality.MEDIUM),
):
    """
    MJPEG video stream endpoint.

    This returns a multipart/x-mixed-replace stream that can be
    displayed directly in an <img> tag or consumed by a video player.

    Target latency: <500ms
    """
    stream_session = camera_service.get_session(session)
    if not stream_session:
        raise HTTPException(status_code=404, detail="Invalid session")

    if stream_session.camera_id != camera_id:
        raise HTTPException(status_code=403, detail="Session/camera mismatch")

    return StreamingResponse(
        camera_service.generate_mjpeg_stream(camera_id, session),
        media_type="multipart/x-mixed-replace; boundary=frame",
        headers={
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "Expires": "0",
            "Connection": "keep-alive",
        },
    )


# =============================================================================
# WebSocket Stream (Alternative low-latency approach)
# =============================================================================

@router.websocket("/{camera_id}/ws")
async def camera_websocket(
    websocket: WebSocket,
    camera_id: str,
):
    """
    WebSocket endpoint for camera frames.

    Provides even lower latency than MJPEG for capable clients.
    Frames are sent as binary JPEG data.
    """
    await camera_service.add_viewer(camera_id, websocket)

    try:
        while True:
            # Receive commands from client
            data = await websocket.receive_json()
            command = data.get("command")

            if command == "ping":
                await websocket.send_json({"type": "pong"})

            elif command == "snapshot":
                # Capture and send snapshot
                snapshot = await camera_service.capture_snapshot(
                    robot_id=data.get("robot_id", "unknown"),
                    camera_id=camera_id,
                )
                await websocket.send_json({
                    "type": "snapshot",
                    "data": snapshot.model_dump(mode="json"),
                })

            elif command == "settings":
                # Update settings
                updates = data.get("settings", {})
                settings = camera_service.update_settings(camera_id, updates)
                await websocket.send_json({
                    "type": "settings",
                    "data": settings.model_dump(mode="json"),
                })

    except WebSocketDisconnect:
        camera_service.remove_viewer(camera_id, websocket)


# =============================================================================
# Snapshots
# =============================================================================

@router.post("/snapshot", response_model=Snapshot)
async def capture_snapshot(request: SnapshotRequest):
    """Capture a snapshot from the camera."""
    return await camera_service.capture_snapshot(
        robot_id=request.robot_id,
        camera_id=request.camera_id,
        quality=request.quality,
        include_metadata=request.include_metadata,
    )


@router.get("/snapshots/{snapshot_id}", response_model=Snapshot)
async def get_snapshot(snapshot_id: str):
    """Get snapshot metadata."""
    snapshot = camera_service.get_snapshot(snapshot_id)
    if not snapshot:
        raise HTTPException(status_code=404, detail="Snapshot not found")
    return snapshot


@router.get("/snapshots/{snapshot_id}/image")
async def get_snapshot_image(snapshot_id: str):
    """Get snapshot image data."""
    data = camera_service.get_snapshot_data(snapshot_id)
    if not data:
        raise HTTPException(status_code=404, detail="Snapshot not found")

    return Response(
        content=data,
        media_type="image/jpeg",
        headers={"Content-Disposition": f"inline; filename={snapshot_id}.jpg"},
    )


@router.get("/snapshots/{snapshot_id}/thumbnail")
async def get_snapshot_thumbnail(snapshot_id: str):
    """Get snapshot thumbnail (same as image for now)."""
    return await get_snapshot_image(snapshot_id)


@router.get("/robot/{robot_id}/snapshots", response_model=list[Snapshot])
async def get_robot_snapshots(
    robot_id: str,
    limit: int = Query(20, ge=1, le=100),
):
    """Get recent snapshots for a robot."""
    return camera_service.get_snapshots_for_robot(robot_id, limit)


# =============================================================================
# Statistics
# =============================================================================

@router.get("/{camera_id}/stats", response_model=CameraStats)
async def get_camera_stats(camera_id: str):
    """Get camera streaming statistics."""
    return camera_service.get_stats(camera_id)
