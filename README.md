# StairDOC Monorepo

This repository houses both the Flutter mobile controller and the FastAPI backend that power the StairDOC autonomous stair-climbing delivery robot. The codebase now follows a structured monorepo layout so each surface can evolve independently while sharing documentation, automation, and release workflows.

## Repository Layout

```
apps/
  mobile/          # Flutter application (Android, iOS, desktop, web)
services/
  api/             # FastAPI + SQLModel backend service
packages/          # Reserved for future shared packages (Dart/Python)
infra/             # Infrastructure-as-code, docker-compose, deployment scripts
scripts/           # Cross-project helper scripts and tooling
docs/              # Architecture notes, runbooks, API references
```

## Getting Started

### Prerequisites
- Flutter 3.x with required platform toolchains (`flutter doctor` should report no issues).
- Python 3.11+ for the backend along with a virtual environment manager (venv, uv, poetry, etc.).

### Mobile App (`apps/mobile`)
```bash
cd apps/mobile
flutter pub get
flutter run  # add --dart-define flags for environment overrides
flutter analyze
flutter test
```
Refer to `apps/mobile/README.md` for feature-level details, environment variables, and mock auth instructions.

### Backend API (`services/api`)
```bash
cd services/api
python -m venv .venv
. .venv/Scripts/activate       # PowerShell: .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
cp .env.example .env           # or use your secret manager
uvicorn app.main:app --reload
```
See `services/api/README.md` for route descriptions, environment variables, and deployment notes.

## Workflow Tips
- Keep Flutter- and backend-specific dependencies inside their respective folders; avoid installing tooling at the repo root.
- Add unit/widget tests next to the code they validate (`apps/mobile/test`, `services/api/tests`).
- Use the `infra/` folder for Docker, CI scripts, and infrastructure definitions so deployments stay discoverable.
- Document shared decisions inside `docs/` and update this README when the layout evolves.

With this structure, future services (e.g., telemetry ingestion, simulation harnesses) can join the monorepo under `services/` while still sharing automation.
