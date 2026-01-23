from collections.abc import AsyncGenerator

from sqlmodel import SQLModel
from sqlmodel.ext.asyncio.session import AsyncSession
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

from .config import get_settings

_settings = get_settings()
_engine: AsyncEngine = create_async_engine(_settings.database_url, echo=False)


async def init_db() -> None:
    # Import all models to ensure they are registered with SQLModel metadata
    # Import order matters for foreign key resolution
    from ..models.user import User  # noqa: F401
    from ..models.robot_unit import RobotUnit  # noqa: F401
    from ..models.delivery_job import DeliveryJob  # noqa: F401
    from ..models.access_log import AccessLog  # noqa: F401
    
    async with _engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.create_all)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    async_session = AsyncSession(_engine, expire_on_commit=False)
    try:
        yield async_session
    finally:
        await async_session.close()
