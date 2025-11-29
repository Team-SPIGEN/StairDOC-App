from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import select

from ..core.database import get_session
from ..core.security import generate_guid
from ..models.delivery_job import DeliveryJob
from ..schemas.delivery import DeliveryJobCreate, DeliveryJobRead, DeliveryJobUpdate
from .deps import get_current_user

router = APIRouter(prefix="/delivery", tags=["delivery"])


@router.get("/jobs", response_model=List[DeliveryJobRead])
async def list_jobs(session=Depends(get_session), _=Depends(get_current_user)):
    result = await session.exec(select(DeliveryJob))
    return result.all()


@router.post("/jobs", response_model=DeliveryJobRead)
async def create_job(payload: DeliveryJobCreate, session=Depends(get_session), _=Depends(get_current_user)):
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
    return job


@router.patch("/jobs/{job_id}", response_model=DeliveryJobRead)
async def update_job(job_id: str, payload: DeliveryJobUpdate, session=Depends(get_session), _=Depends(get_current_user)):
    result = await session.exec(select(DeliveryJob).where(DeliveryJob.id == job_id))
    job = result.one_or_none()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    if payload.status is not None:
        job.status = payload.status
    if payload.assigned_robot_id is not None:
        job.assigned_robot_id = payload.assigned_robot_id
    job.updated_at = datetime.utcnow()
    await session.commit()
    await session.refresh(job)
    return job


@router.delete("/jobs/{job_id}")
async def delete_job(job_id: str, session=Depends(get_session), _=Depends(get_current_user)):
    result = await session.exec(select(DeliveryJob).where(DeliveryJob.id == job_id))
    job = result.one_or_none()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    await session.delete(job)
    await session.commit()
    return {"deleted": True}
