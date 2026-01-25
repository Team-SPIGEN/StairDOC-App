"""
Container access control API endpoints.

Provides endpoints for:
- Locking/unlocking the robot's document container
- Retrieving access logs with pagination and filtering
- Querying current container status

Optimized for high throughput with caching.
"""

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import select, func
from sqlmodel.ext.asyncio.session import AsyncSession

from ..core.database import get_session
from ..core.cache import get_cache, ACCESS_LOG_TTL
from ..models.access_log import AccessLog
from ..models.user import User
from ..schemas.access import (
    AccessLogListResponse,
    AccessLogResponse,
    AccessMethod,
    ContainerAction,
    ContainerStatusResponse,
    LockUnlockRequest,
    LockUnlockResponse,
)
from ..services.container_service import (
    ContainerState,
    HardwareConnectionError,
    container_service,
)
from .deps import get_current_user

router = APIRouter(prefix="/container", tags=["container"])


@router.post("/unlock", response_model=LockUnlockResponse)
async def unlock_container(
    request: LockUnlockRequest = LockUnlockRequest(),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """
    Unlock the robot's document container.
    
    This endpoint:
    1. Sends unlock command to the Raspberry Pi
    2. Logs the action in the database
    3. Returns the result
    
    Requires authentication. All unlock attempts are logged,
    including failures.
    """
    timestamp = datetime.utcnow()
    location = request.location or f"Floor {request.floor or '?'} - Zone {request.zone or '?'}"
    
    try:
        # Send command to hardware
        result = await container_service.send_unlock_command()
        
        # Log successful action
        log_entry = AccessLog(
            user_id=current_user.id,
            user_name=current_user.full_name or current_user.email,
            action=ContainerAction.UNLOCK.value,
            location=location,
            floor=request.floor,
            zone=request.zone,
            timestamp=timestamp,
            status="success",
            method=request.method.value,
        )
        session.add(log_entry)
        await session.commit()
        await session.refresh(log_entry)
        
        return LockUnlockResponse(
            status="success",
            action=ContainerAction.UNLOCK,
            timestamp=timestamp,
            message="Container unlocked successfully",
            log_id=log_entry.id,
        )
        
    except HardwareConnectionError as e:
        # Log failed action
        log_entry = AccessLog(
            user_id=current_user.id,
            user_name=current_user.full_name or current_user.email,
            action=ContainerAction.UNLOCK.value,
            location=location,
            floor=request.floor,
            zone=request.zone,
            timestamp=timestamp,
            status="failed",
            error_message=str(e),
            method=request.method.value,
        )
        session.add(log_entry)
        await session.commit()
        
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Hardware communication failed: {e}",
        )


@router.post("/lock", response_model=LockUnlockResponse)
async def lock_container(
    request: LockUnlockRequest = LockUnlockRequest(),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """
    Lock the robot's document container.
    
    This endpoint:
    1. Sends lock command to the Raspberry Pi
    2. Logs the action in the database
    3. Returns the result
    
    Requires authentication. All lock attempts are logged,
    including failures.
    """
    timestamp = datetime.utcnow()
    location = request.location or f"Floor {request.floor or '?'} - Zone {request.zone or '?'}"
    
    try:
        # Send command to hardware
        result = await container_service.send_lock_command()
        
        # Log successful action
        log_entry = AccessLog(
            user_id=current_user.id,
            user_name=current_user.full_name or current_user.email,
            action=ContainerAction.LOCK.value,
            location=location,
            floor=request.floor,
            zone=request.zone,
            timestamp=timestamp,
            status="success",
            method=request.method.value,
        )
        session.add(log_entry)
        await session.commit()
        await session.refresh(log_entry)
        
        return LockUnlockResponse(
            status="success",
            action=ContainerAction.LOCK,
            timestamp=timestamp,
            message="Container locked successfully",
            log_id=log_entry.id,
        )
        
    except HardwareConnectionError as e:
        # Log failed action
        log_entry = AccessLog(
            user_id=current_user.id,
            user_name=current_user.full_name or current_user.email,
            action=ContainerAction.LOCK.value,
            location=location,
            floor=request.floor,
            zone=request.zone,
            timestamp=timestamp,
            status="failed",
            error_message=str(e),
            method=request.method.value,
        )
        session.add(log_entry)
        await session.commit()
        
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Hardware communication failed: {e}",
        )


@router.get("/logs", response_model=AccessLogListResponse)
async def get_access_logs(
    limit: int = Query(default=50, ge=1, le=100, description="Max logs to return"),
    offset: int = Query(default=0, ge=0, description="Number of logs to skip"),
    action: Optional[str] = Query(default=None, description="Filter by action: 'lock' or 'unlock'"),
    status_filter: Optional[str] = Query(
        default=None, 
        alias="status",
        description="Filter by status: 'success', 'failed', or 'denied'"
    ),
    user_id: Optional[str] = Query(default=None, description="Filter by user ID"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """
    Retrieve paginated access logs with optional filtering.
    
    Returns logs in reverse chronological order (most recent first).
    Supports filtering by action type, status, and user.
    
    Cached for 60 seconds to reduce database load.
    """
    cache = get_cache()
    
    # Build cache key
    cache_key = f"access:logs:l{limit}:o{offset}"
    if action:
        cache_key += f":a={action}"
    if status_filter:
        cache_key += f":s={status_filter}"
    if user_id:
        cache_key += f":u={user_id}"
    
    # Try cache
    cached = await cache.get(cache_key)
    if cached:
        return AccessLogListResponse(**cached)
    
    # Build query
    query = select(AccessLog)
    count_query = select(func.count(AccessLog.id))
    
    # Apply filters
    if action:
        query = query.where(AccessLog.action == action)
        count_query = count_query.where(AccessLog.action == action)
    
    if status_filter:
        query = query.where(AccessLog.status == status_filter)
        count_query = count_query.where(AccessLog.status == status_filter)
    
    if user_id:
        query = query.where(AccessLog.user_id == user_id)
        count_query = count_query.where(AccessLog.user_id == user_id)
    
    # Get total count
    total_result = await session.execute(count_query)
    total = total_result.scalar() or 0
    
    # Get paginated results
    query = query.order_by(AccessLog.timestamp.desc()).offset(offset).limit(limit)
    result = await session.execute(query)
    logs = result.scalars().all()
    
    response = AccessLogListResponse(
        logs=[AccessLogResponse.model_validate(log) for log in logs],
        total=total,
        limit=limit,
        offset=offset,
        has_more=(offset + len(logs)) < total,
    )
    
    # Cache the response
    await cache.set(cache_key, response.model_dump(), ACCESS_LOG_TTL)
    
    return response


@router.get("/logs/{log_id}", response_model=AccessLogResponse)
async def get_access_log(
    log_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """
    Retrieve a single access log entry by ID.
    """
    query = select(AccessLog).where(AccessLog.id == log_id)
    result = await session.execute(query)
    log = result.scalar_one_or_none()
    
    if not log:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Access log {log_id} not found",
        )
    
    return AccessLogResponse.model_validate(log)


@router.get("/status", response_model=ContainerStatusResponse)
async def get_container_status(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """
    Get current container lock status.
    
    Returns the current lock state from hardware, plus the last
    action from the database for context.
    """
    # Get hardware status
    hw_status = await container_service.get_status()
    
    # Get last action from database
    query = (
        select(AccessLog)
        .where(AccessLog.status == "success")
        .order_by(AccessLog.timestamp.desc())
        .limit(1)
    )
    result = await session.execute(query)
    last_log = result.scalar_one_or_none()
    
    return ContainerStatusResponse(
        is_locked=hw_status.state == ContainerState.LOCKED,
        last_action=last_log.action if last_log else None,
        last_action_by=last_log.user_name if last_log else None,
        last_action_at=last_log.timestamp if last_log else None,
        robot_id=None,  # TODO: Get from robot registry
    )
