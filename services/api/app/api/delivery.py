"""
Delivery job API with caching and pagination for high throughput.

Optimized for 1000+ requests/min with:
- Redis/local caching of job lists
- Pagination for large result sets
- Cache invalidation on mutations
"""

from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlmodel import select, func

from ..core.database import get_session
from ..core.security import generate_guid
from ..core.cache import get_cache, DELIVERY_QUEUE_TTL
from ..models.delivery_job import DeliveryJob
from ..schemas.delivery import DeliveryJobCreate, DeliveryJobRead, DeliveryJobUpdate
from ..utils.pagination import (
    PageParams, PageInfo, PaginatedResponse,
    paginate_query, create_page_info,
)
from .deps import get_current_user

router = APIRouter(prefix="/delivery", tags=["delivery"])


@router.get("/jobs", response_model=PaginatedResponse[DeliveryJobRead])
async def list_jobs(
    page: int = Query(default=1, ge=1, description="Page number"),
    page_size: int = Query(default=20, ge=1, le=100, description="Items per page"),
    status: Optional[str] = Query(default=None, description="Filter by status"),
    robot_id: Optional[str] = Query(default=None, description="Filter by robot"),
    session=Depends(get_session),
    _=Depends(get_current_user),
):
    """
    List delivery jobs with pagination and filtering.
    
    Cached for 30 seconds to reduce database load.
    """
    cache = get_cache()
    params = PageParams(page=page, page_size=page_size)
    
    # Build cache key based on filters
    cache_key = f"delivery:list:p{page}:s{page_size}"
    if status:
        cache_key += f":status={status}"
    if robot_id:
        cache_key += f":robot={robot_id}"
    
    # Try cache first
    cached = await cache.get(cache_key)
    if cached:
        return PaginatedResponse[DeliveryJobRead](**cached)
    
    # Build query
    stmt = select(DeliveryJob)
    if status:
        stmt = stmt.where(DeliveryJob.status == status)
    if robot_id:
        stmt = stmt.where(DeliveryJob.assigned_robot_id == robot_id)
    
    # Get total count
    count_stmt = select(func.count()).select_from(stmt.subquery())
    count_result = await session.execute(count_stmt)
    total = count_result.scalar() or 0
    
    # Apply pagination and ordering
    stmt = stmt.order_by(DeliveryJob.created_at.desc())
    stmt = stmt.offset(params.offset).limit(params.limit)
    
    result = await session.execute(stmt)
    jobs = result.scalars().all()
    
    page_info = create_page_info(page, page_size, total)
    
    response = PaginatedResponse[DeliveryJobRead](
        items=[DeliveryJobRead.model_validate(j) for j in jobs],
        page_info=page_info,
    )
    
    # Cache the response
    await cache.set(cache_key, response.model_dump(), DELIVERY_QUEUE_TTL)
    
    return response


@router.get("/jobs/pending", response_model=List[DeliveryJobRead])
async def list_pending_jobs(
    session=Depends(get_session),
    _=Depends(get_current_user),
):
    """
    Get pending/in-progress jobs (cached for quick access).
    
    This is a frequently accessed endpoint for the dashboard.
    """
    cache = get_cache()
    cache_key = cache.delivery_queue_key()
    
    # Try cache first
    cached = await cache.get(cache_key)
    if cached:
        return [DeliveryJobRead.model_validate(j) for j in cached]
    
    # Query database
    stmt = select(DeliveryJob).where(
        DeliveryJob.status.in_(["pending", "in_progress"])
    ).order_by(DeliveryJob.created_at.desc())
    
    result = await session.execute(stmt)
    jobs = result.scalars().all()
    
    # Cache the result
    job_list = [j.model_dump() for j in jobs]
    await cache.set(cache_key, job_list, DELIVERY_QUEUE_TTL)
    
    return jobs


@router.get("/jobs/{job_id}", response_model=DeliveryJobRead)
async def get_job(
    job_id: str,
    session=Depends(get_session),
    _=Depends(get_current_user),
):
    """Get a single delivery job by ID."""
    cache = get_cache()
    cache_key = cache.delivery_job_key(job_id)
    
    # Try cache
    cached = await cache.get(cache_key)
    if cached:
        return DeliveryJobRead.model_validate(cached)
    
    result = await session.execute(
        select(DeliveryJob).where(DeliveryJob.id == job_id)
    )
    job = result.scalar_one_or_none()
    
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    # Cache for future requests
    await cache.set(cache_key, job.model_dump(), DELIVERY_QUEUE_TTL)
    
    return job


@router.post("/jobs", response_model=DeliveryJobRead)
async def create_job(
    payload: DeliveryJobCreate,
    session=Depends(get_session),
    _=Depends(get_current_user),
):
    """Create a new delivery job."""
    job = DeliveryJob(
        id=generate_guid(),
        title=payload.title,
        pickup_zone=payload.pickup_zone,
        dropoff_zone=payload.dropoff_zone,
        requested_by=payload.requested_by,
        assigned_robot_id=payload.assigned_robot_id,
    )
    session.add(job)
    await session.commit()
    await session.refresh(job)
    
    # Invalidate cache
    cache = get_cache()
    await cache.delete_pattern("delivery:*")
    
    return job


@router.patch("/jobs/{job_id}", response_model=DeliveryJobRead)
async def update_job(
    job_id: str,
    payload: DeliveryJobUpdate,
    session=Depends(get_session),
    _=Depends(get_current_user),
):
    """Update a delivery job."""
    result = await session.execute(
        select(DeliveryJob).where(DeliveryJob.id == job_id)
    )
    job = result.scalar_one_or_none()
    
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    if payload.status is not None:
        job.status = payload.status
    if payload.assigned_robot_id is not None:
        job.assigned_robot_id = payload.assigned_robot_id
    job.updated_at = datetime.utcnow()
    
    await session.commit()
    await session.refresh(job)
    
    # Invalidate cache
    cache = get_cache()
    await cache.delete(cache.delivery_job_key(job_id))
    await cache.delete_pattern("delivery:list:*")
    await cache.delete(cache.delivery_queue_key())
    
    return job


@router.delete("/jobs/{job_id}")
async def delete_job(
    job_id: str,
    session=Depends(get_session),
    _=Depends(get_current_user),
):
    """Delete a delivery job."""
    result = await session.execute(
        select(DeliveryJob).where(DeliveryJob.id == job_id)
    )
    job = result.scalar_one_or_none()
    
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    await session.delete(job)
    await session.commit()
    
    # Invalidate cache
    cache = get_cache()
    await cache.delete(cache.delivery_job_key(job_id))
    await cache.delete_pattern("delivery:list:*")
    await cache.delete(cache.delivery_queue_key())
    
    return {"deleted": True}
