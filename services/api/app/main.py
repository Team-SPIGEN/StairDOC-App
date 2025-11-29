from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api import auth, delivery, health, robot
from .core.config import get_settings
from .core.database import init_db

settings = get_settings()
app = FastAPI(title=settings.app_name)

if settings.allowed_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.allowed_origins),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


@app.on_event("startup")
async def on_startup() -> None:
    await init_db()


app.include_router(health.router)
app.include_router(auth.router, prefix=settings.api_v1_prefix)
app.include_router(robot.router, prefix=settings.api_v1_prefix)
app.include_router(delivery.router, prefix=settings.api_v1_prefix)
