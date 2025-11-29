from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect

from ..schemas.robot import CommandRequest, RobotEndpoint, RobotStatus
from ..services.robot_registry import robot_registry
from .deps import get_current_user

router = APIRouter(prefix="/robot", tags=["robot"])


@router.get("/discovery", response_model=List[RobotEndpoint])
async def list_robot_endpoints(_=Depends(get_current_user)):
    return list(robot_registry.list_endpoints())


@router.post("/register", response_model=RobotEndpoint)
async def register_robot(endpoint: RobotEndpoint):
    robot_registry.register_endpoint(endpoint)
    robot_registry.update_status(RobotStatus(id=endpoint.id, status_message="Registered", last_seen=datetime.utcnow()))
    return endpoint


@router.post("/status", response_model=RobotStatus)
async def update_status(status: RobotStatus):
    robot_registry.update_status(status)
    return status


@router.post("/command")
async def issue_command(command: CommandRequest, _=Depends(get_current_user)):
    # Stub: forward to actual robot transport (HTTP, MQTT, etc.)
    if command.direction not in {"forward", "backward", "left", "right", "stop"}:
        raise HTTPException(status_code=400, detail="Unsupported direction")
    return {"accepted": True, "direction": command.direction}


@router.websocket("/ws/status")
async def robot_status_ws(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            payload = [status.model_dump() for status in robot_registry.list_status()]
            await websocket.send_json(payload)
            await websocket.receive_text()
    except WebSocketDisconnect:
        return
