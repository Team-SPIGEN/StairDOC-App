# StairDOC Copilot Instructions

## Mission Snapshot
- Build a multi-platform Flutter app that fully manages StairDoc, an autonomous stair-climbing delivery robot for intra-office document transport.
- `lib/main.dart` will stay lean: configure theme, global providers, and route table; put feature logic in dedicated modules under `lib/`.
- Material 3 with dark mode is the design baseline; seed themes via `ColorScheme.fromSeed` and expose toggles through app settings.

## Planned Structure & Ownership
- Adopt the folder layout outlined in the project brief: `models/`, `services/`, `providers/`, `screens/`, `widgets/`, `utils/`. Create missing folders as features land and keep files focused (one class/widget per file when practical).
- State management should use Provider or Riverpod; register app-wide providers in `main.dart` and keep API/service dependencies injected for testability.
- Networking relies on REST + WebSocket/FCM; favor `dio` or `http` for REST, plus a dedicated WebSocket/FCM client inside `robot_api_service.dart` and `notification_service.dart`.
- Cache critical slices (auth session, last robot status, pending jobs) via `Hive` or `sqflite`; wrap local persistence behind helper methods in `services/`.

## Feature Pillars & Key Screens
- **Authentication**: Implement role-aware login/registration in `auth_service.dart` backed by Firebase Auth or a JWT API. Expose session state through `auth_provider.dart`. Ensure RFID fields and profile management live in `models/user.dart`.
- **Robot Dashboard**: `dashboard_screen.dart` aggregates robot vitals (floor, zone, battery, payload, state, connectivity). Compose UI with reusable widgets (`robot_status_card.dart`, `battery_indicator.dart`, `floor_indicator.dart`). Subscribe to live updates via WebSocket streams.
- **Container Access Control**: Lock/unlock actions go through `robot_api_service.dart` (POST `/api/container/lock|unlock`). Log entries map to `models/access_log.dart` and render in `access_log_screen.dart` with timeline visuals and photo thumbnails.
- **Delivery Scheduling**: `delivery_screen.dart` handles job creation, queue listing, and status tracking using `delivery_provider.dart`. Persist history locally for offline review and sync with `/api/delivery/*` endpoints.
- **Voice Interface**: Route microphone input through `voice_service.dart` (packages: `speech_to_text`, `flutter_tts`). Supported commands should map to endpoints or WebSocket messages; capture errors gracefully with in-app feedback.
- **Notifications & Camera**: Use FCM/push for critical alerts; surface them via an in-app notification center. Live video and unlock snapshots originate from `/api/camera/stream` or similar—abstract transport details in `camera_service.dart`.
- **Safety & Manual Control**: Prominent emergency stop widget publishing to `/api/voice-command` or dedicated endpoint. Manual drive controls live in a testing tab; gate them behind admin role checks.

## Backend Touchpoints
- REST endpoints to integrate (per brief): login, robot status/location, container lock/unlock, access logs, delivery job CRUD, voice command, camera stream, notifications.
- Document Raspberry Pi integration hooks directly inside service methods (concise comments), describing expected payloads and retry/backoff logic for lost connectivity.
- Maintain a central constants file (`utils/api_endpoints.dart`) so base URLs, ports, and WebSocket paths remain editable without code spelunking.

## Workflow Essentials
- Commands: `flutter pub get`, `flutter run -d <device>`, `flutter analyze`, `flutter test`. Prefer `flutter test --coverage` when validating provider/service additions.
- Add new dependencies in `pubspec.yaml`, run `flutter pub get`, and commit the resulting `pubspec.lock` diff. Document any native platform setup steps (e.g., iOS camera permissions) in the README.
- Use feature branches per module (e.g., `feature/delivery-scheduling`); keep PRs focused on one vertical slice to simplify review.

## Testing & Observability
- Mirror `lib/` structure under `test/`; add widget tests for key screens and unit tests for providers/services (mock REST/WebSocket). For async flows, rely on `pumpAndSettle()` and `fake_async` utilities.
- When integrating with live robot hardware, create mock adapters to keep CI green. Mention hardware-only steps in comments or dedicated docs.

## Housekeeping
- Keep `.github/copilot-instructions.md` and `README.md` aligned whenever workflows or dependencies change.
- Update platform-specific manifests (Android, iOS, etc.) when introducing permissions (camera, mic, push). Track bundle identifiers and network security configs alongside backend changes.
