# StairDOC - Autonomous Stair-Climbing Delivery Robot

[![Backend Tests](https://img.shields.io/badge/tests-541%20passed-brightgreen)]()
[![Coverage](https://img.shields.io/badge/coverage-71.64%25-yellow)]()
[![Flutter](https://img.shields.io/badge/Flutter-3.9%2B-blue)]()
[![FastAPI](https://img.shields.io/badge/FastAPI-0.114-green)]()

Multi-platform control system for StairDOC, an autonomous stair-climbing document delivery robot for intra-office transport.

## 🚀 Features

- **Real-time Robot Control** - Live telemetry, movement commands, emergency stop
- **Voice Commands** - Natural language control via speech recognition
- **Delivery Management** - Schedule, track, and manage document deliveries
- **Secure Container Access** - RFID, app, and voice-based lock/unlock
- **Live Camera Feed** - MJPEG streaming with snapshots
- **Push Notifications** - Real-time delivery and robot status alerts
- **Multi-platform** - Android, iOS, Web, Windows, macOS, Linux

## 📁 Repository Structure

```
├── apps/
│   └── mobile/              # Flutter application
├── services/
│   └── api/                 # FastAPI backend
├── infra/                   # Infrastructure & deployment
├── docs/                    # Documentation
└── scripts/                 # Build & automation scripts
```

## 🏃 Quick Start

### Prerequisites

- **Flutter** 3.9+ (`flutter doctor` should pass)
- **Python** 3.11+ with pip
- **Node.js** 18+ (optional, for web development)

### Backend API

```bash
cd services/api

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Run development server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**URLs:**
- API Docs: http://localhost:8000/docs
- Health: http://localhost:8000/health

### Mobile App

```bash
cd apps/mobile

# Get dependencies
flutter pub get

# Run (development)
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1

# Run tests
flutter test

# Analyze code
flutter analyze
```

## 🐳 Production Deployment

### Docker (Recommended)

```bash
cd services/api

# Configure production secrets
cp .env.production .env
# Edit .env with secure values

# Start services (API, PostgreSQL, Redis, Traefik)
docker-compose -f docker-compose.prod.yml up -d
```

### Manual Deployment

See [services/api/README.md](services/api/README.md) for detailed deployment instructions.

### Flutter Production Build

```powershell
cd apps/mobile

# Windows
.\scripts\build_production.ps1 -ApiBaseUrl "https://api.yourdomain.com/api/v1"

# Linux/macOS
./scripts/build_production.sh
```

## 📊 Test Coverage

| Component | Tests | Coverage |
|-----------|-------|----------|
| Backend API | 541 | 71.64% |
| Flutter App | - | - |

Run tests:
```bash
# Backend
cd services/api
pytest --cov=app --cov-report=html

# Flutter
cd apps/mobile
flutter test --coverage
```

## 🔧 Configuration

### Backend Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SECRET_KEY` | JWT signing key | Required |
| `DATABASE_URL` | Database connection | SQLite |
| `REDIS_URL` | Cache connection | None |
| `ALLOWED_ORIGINS` | CORS origins | "" |
| `DEBUG` | Debug mode | false |

### Flutter Build Flags

| Flag | Description | Default |
|------|-------------|---------|
| `API_BASE_URL` | Backend API URL | localhost |
| `ENVIRONMENT` | development/production | development |
| `ENABLE_MOCK_AUTH` | Use mock authentication | false |

## 📱 API Overview

| Category | Endpoints |
|----------|-----------|
| **Auth** | `/auth/login`, `/auth/register`, `/auth/refresh` |
| **Robot** | `/robot/discovery`, `/robot/command`, `/robot/status` |
| **Delivery** | `/delivery/jobs` (CRUD) |
| **Container** | `/container/lock`, `/container/unlock`, `/container/logs` |
| **Voice** | `/voice/command`, `/voice/capabilities` |
| **Camera** | `/camera/stream`, `/camera/snapshot` |
| **Notifications** | `/notifications`, WebSocket |

Full API documentation: http://localhost:8000/docs

## 🔒 Security

- JWT authentication with refresh tokens
- Rate limiting (100 req/min default)
- Input validation & sanitization
- CORS protection
- Security headers (HSTS, CSP, etc.)
- Password requirements (8+ chars, mixed case, numbers, symbols)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open a Pull Request

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- University of Moratuwa - IoT Project
- Flutter & FastAPI communities
