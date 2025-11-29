# StairDOC Delivery Robot Control

> This document describes the Flutter application located under `apps/mobile` within the StairDOC monorepo.

StairDOC is a multi-platform Flutter application that manages authentication and secure access for the StairDoc autonomous stair-climbing delivery robot. The current slice implements a production-grade authentication experience that follows Material Design 3, supports light/dark themes, and integrates with the robot control backend.

## Feature Highlights

- Material 3 compliant UI with teal brand palette, dark/cream backgrounds, and Inter typography via Google Fonts
- BLoC-driven authentication state (login, registration, logout, forgot password) with form validation and live feedback
- Dio-based API client with structured error handling and PrettyDioLogger for diagnostics
- Secure token storage via `flutter_secure_storage` and role/profile caching with `SharedPreferences`
- GoRouter navigation with auth guards, splash boot flow, and responsive transitions
- Reusable UI building blocks (`CustomTextField`, `CustomButton`, `LoadingOverlay`) tuned for accessibility and consistent spacing

## Project Structure

```
lib/
  models/                // DTOs (User, AuthResponse)
  providers/auth/        // AuthBloc, events, states
  routes/                // GoRouter configuration and auth guards
  screens/               // Splash + Auth + Dashboard screens
  services/              // API client, AuthService, secure/local storage
  theme/                 // Material 3 light/dark themes
  utils/                 // API endpoints, validators, spacing constants
  widgets/               // Reusable UI components
```

## Backend Integration

- Base URL defaults to `http://192.168.1.100:8000/api/v1`.
- Endpoints:
  - `POST /auth/login`
  - `POST /auth/register`
  - `POST /auth/forgot-password`
- Override the base URL per build with Dart defines:
	```bash
	flutter run --dart-define=API_BASE_URL=https://staging.api.stairdoc.com/api/v1
	```

## Getting Started

1. **Install dependencies**
	```bash
	flutter pub get
	```

2. **Configure platform tooling**
	- Ensure Android/iOS platform requirements are met (Flutter doctor should report no issues).
	- If targeting physical devices, connect them before running `flutter run`.

3. **Run the app**
	```bash
	flutter run
	```
	The splash screen checks stored credentials and automatically routes to the dashboard or login screen.

4. **Execute static analysis & tests**
	```bash
	flutter analyze
	flutter test
	```

## Environment & Secrets

- Tokens are stored with `flutter_secure_storage`; no credentials should be hard-coded.
- Shared preferences cache the last authenticated user and role to drive quick re-entry.
	- Mock authentication is available for development to bypass backend dependencies:
		```bash
		flutter run \
			--dart-define=ENABLE_MOCK_AUTH=true \
			--dart-define=MOCK_EMAIL=operator@stairdoc.dev \
			--dart-define=MOCK_PASSWORD=Password123! \
			--dart-define=MOCK_NAME="Dev Operator" \
			--dart-define=MOCK_ROLE=operator
		```
		* Sign in with the supplied mock credentials to land on the dashboard instantly.
		* Adjust `MOCK_AUTH_LATENCY_MS` to emulate slower connections, or omit the defines to fall back to the real backend.
	- When integrating new environments, prefer Dart defines for URLs/secrets instead of editing source files directly.

## Next Steps

- Flesh out the dashboard with live robot telemetry and delivery scheduling flows.
- Layer in Provider/DI wiring for hardware simulators vs. production services.
- Expand test coverage: add widget tests for each authentication screen and bloc tests for success/error paths.
