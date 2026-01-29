# StairDOC API Backend

High-performance FastAPI backend for the StairDOC autonomous delivery robot control system.

## Features

- 🚀 **High Throughput**: 1000+ requests/minute with connection pooling
- 🔐 **Secure**: JWT authentication, rate limiting, input validation
- 📊 **Monitoring**: Structured JSON logging, health checks, metrics
- 🐳 **Docker Ready**: Production-grade containerization
- 🔄 **Real-time**: WebSocket support for live telemetry

## Quick Start (Development)

```bash
cd services/api

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env

# Run development server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**URLs:**
- Swagger UI: http://localhost:8000/docs
- Health Check: http://localhost:8000/health
- ReDoc: http://localhost:8000/redoc

## Production Deployment

### Option 1: Docker Compose (Recommended)

```bash
# Configure production secrets
cp .env.production .env
# Edit .env with secure values (SECRET_KEY, DB_PASSWORD, etc.)

# Start all services
docker-compose -f docker-compose.prod.yml up -d

# View logs
docker-compose -f docker-compose.prod.yml logs -f api

# Stop services
docker-compose -f docker-compose.prod.yml down
```

### Option 2: Manual Deployment

```bash
# Install production dependencies
pip install gunicorn uvloop httptools

# Run with Gunicorn (4 workers)
gunicorn app.main:app \
  --worker-class uvicorn.workers.UvicornWorker \
  --workers 4 \
  --bind 0.0.0.0:8000 \
  --timeout 120
```

### Database Migrations

```bash
# Install Alembic
pip install alembic

# Create a new migration
alembic revision --autogenerate -m "Add new feature"

# Apply migrations
alembic upgrade head

# Rollback
alembic downgrade -1
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SECRET_KEY` | JWT signing key (min 32 chars) | **Required** |
| `DATABASE_URL` | Database connection string | `sqlite+aiosqlite:///./stairdoc.db` |
| `REDIS_URL` | Redis connection (for caching) | `None` |
| `ALLOWED_ORIGINS` | CORS origins (comma-separated) | `""` |
| `DEBUG` | Enable debug mode | `false` |
| `LOG_LEVEL` | Logging level | `INFO` |
| `RATE_LIMIT_ENABLED` | Enable rate limiting | `true` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | JWT access token TTL | `30` |

See `.env.example` and `.env.production` for full configuration options.

## API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Create account
- `POST /api/v1/auth/login` - Get tokens
- `POST /api/v1/auth/refresh` - Refresh tokens
- `GET /api/v1/auth/me` - Get profile

### Robot Control
- `GET /api/v1/robot/discovery` - List robots
- `POST /api/v1/robot/register` - Register robot
- `POST /api/v1/robot/command` - Send command
- `WS /api/v1/ws/telemetry` - Live telemetry

### Delivery Management
- `GET /api/v1/delivery/jobs` - List jobs
- `POST /api/v1/delivery/jobs` - Create job
- `PATCH /api/v1/delivery/jobs/{id}` - Update job
- `DELETE /api/v1/delivery/jobs/{id}` - Delete job

### Container Access
- `POST /api/v1/container/lock` - Lock container
- `POST /api/v1/container/unlock` - Unlock container
- `GET /api/v1/container/logs` - Access history

### Voice Commands
- `POST /api/v1/voice/command` - Process voice
- `GET /api/v1/voice/capabilities` - List commands

### Camera
- `POST /api/v1/camera/stream/start` - Start stream
- `POST /api/v1/camera/snapshot` - Capture image
- `GET /api/v1/camera/{id}/stream/mjpeg` - MJPEG stream

### Notifications
- `GET /api/v1/notifications` - List notifications
- `POST /api/v1/notifications/test` - Test notification
- `WS /api/v1/notifications/ws/{user_id}` - Real-time

## Project Structure

```
services/api/
├── app/
│   ├── api/           # FastAPI routers
│   ├── core/          # Config, database, security
│   ├── models/        # SQLModel ORM models
│   ├── schemas/       # Pydantic DTOs
│   ├── services/      # Business logic
│   ├── utils/         # Helpers
│   └── main.py        # Application entry
├── migrations/        # Alembic migrations
├── tests/             # Pytest test suite
├── Dockerfile         # Production container
├── docker-compose.prod.yml
├── requirements.txt
├── .env.example       # Development config
└── .env.production    # Production template
```

## Testing

```bash
# Run all tests
pytest

# With coverage
pytest --cov=app --cov-report=html

# Specific module
pytest tests/api/test_auth.py -v
```

## Security Considerations

1. **Always** change `SECRET_KEY` in production
2. Use PostgreSQL (not SQLite) for production
3. Enable HTTPS via reverse proxy (Traefik/Nginx)
4. Set restrictive `ALLOWED_ORIGINS`
5. Enable rate limiting
6. Review and rotate API keys regularly

## Monitoring

Health endpoints for load balancers and monitoring:

```bash
# Simple health check
curl http://localhost:8000/health

# Detailed status
curl http://localhost:8000/health/detailed

# Database health
curl http://localhost:8000/health/database

# Cache stats
curl http://localhost:8000/health/cache
```

## License

MIT License - See [LICENSE](../../LICENSE) for details.
