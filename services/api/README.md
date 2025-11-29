# StairDOC API Backend

FastAPI + SQLModel service that powers the StairDOC mobile controller. It exposes authentication, robot discovery, command, and delivery scheduling endpoints while remaining lightweight enough to run on a Raspberry Pi alongside the robot hardware.

## Folder Structure

```
services/api
├── app
│   ├── api/                # FastAPI routers
│   ├── core/               # config, DB, security helpers
│   ├── models/             # SQLModel ORM tables
│   ├── schemas/            # Pydantic DTOs
│   ├── services/           # Domain helpers (robot registry, notifications)
│   └── main.py             # FastAPI application entrypoint
├── .env.example            # Sample environment variables
├── requirements.txt        # Python dependencies
└── README.md               # This file
```

## Quick Start

```bash
cd services/api
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\\Scripts\\activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Environment Variables

| Name | Description |
| --- | --- |
| `SECRET_KEY` | HMAC secret used to sign JWTs |
| `DATABASE_URL` | SQLAlchemy-style connection string (defaults to local SQLite) |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Access token lifetime |
| `REFRESH_TOKEN_EXPIRE_MINUTES` | Refresh token lifetime |
| `ALLOWED_ORIGINS` | Comma-separated list of allowed CORS origins |

### Useful URLs

- Swagger UI: `http://localhost:8000/docs`
- Health check: `http://localhost:8000/health`

## Robot & Delivery Flow

1. Robots POST `/api/v1/robot/register` with their host/port metadata.
2. Flutter app fetches `/api/v1/robot/discovery` to list units and opens `/api/v1/robot/ws/status` for live telemetry.
3. Movement commands hit `/api/v1/robot/command` (extend to forward to ESP32 via HTTP/MQTT).
4. Delivery jobs are managed through `/api/v1/delivery/jobs` CRUD endpoints.

## Next Steps

- Swap SQLite for PostgreSQL in production (`DATABASE_URL=postgresql+asyncpg://...`).
- Protect robot registration with API keys or mutual TLS.
- Integrate real notification channels inside `services/notification_service.py`.
- Add Alembic migrations once schema stabilizes.
