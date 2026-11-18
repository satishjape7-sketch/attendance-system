# Attend — Flutter + Node.js + PostgreSQL

A single-organization employee attendance application. Employees sign in, check in/out once per business day, review paginated history, and change passwords. Administrators create employees, activate/deactivate employees, and review paginated team reports with date filters.

## Repository

```
backend/
  src/
    config/           # Validated environment configuration
    database/         # Connection pool, migration runner, operator commands
    middleware/       # Authentication and administrator authorization
    lib/              # Shared validation and errors
    modules/
      auth/           # Login, profile, logout, password change
      attendance/     # Check-in/out, history, reports
      users/          # Employee management and audit trail
    app.js            # HTTP composition and error handling
    server.js         # Startup and graceful shutdown
  migrations/         # Ordered PostgreSQL schema migrations
  test/               # Validation, HTTP, PostgreSQL integration tests
mobile/
  lib/
    app/              # Application state, theme, navigation
    core/             # API transport and secure token storage
    features/
      auth/           # Login, account, user model
      attendance/     # Today, history, reports, attendance model
      users/          # Employee administration
    shared/           # Reusable loading/error controls
  test/
docs/                 # API and deployment notes
compose.yaml          # PostgreSQL, migration job, API
```

## Requirements

Node.js 22+, PostgreSQL 17, Flutter with Dart 3.5+, Android SDK / Xcode as appropriate. Docker Compose is an alternative for the backend. Use `npm.cmd` on Windows if PowerShell blocks `npm.ps1`.

## Backend: local setup

1. In `backend`, copy `.env.example` to `.env`.
2. Create a PostgreSQL database and dedicated application user. Set `DATABASE_URL` to its connection URL.
3. Generate a secret with `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"` and set `JWT_SECRET`.
4. Install and initialize:

```powershell
cd backend
npm.cmd install
npm.cmd run migrate
# Set ADMIN_EMAIL, ADMIN_NAME and ADMIN_PASSWORD in backend/.env first.
npm.cmd run seed:admin
npm.cmd run dev
```

No default login credentials are shipped. Administrator passwords require at least 12 characters and at most 72 UTF-8 bytes. Remove the admin seed password from the environment after seeding.

Liveness: `GET http://localhost:3000/health/live`. Readiness: `GET /health/ready`.

## Backend: Docker Compose

Copy root `.env.example` to root `.env`. Generate distinct random hex values for `POSTGRES_PASSWORD` and `JWT_SECRET`. Hex passwords avoid URL escaping issues in the composed database URL.

```powershell
docker compose up --build -d
# Supply temporary admin variables securely in your shell:
$env:ADMIN_EMAIL = 'admin@example.com'
$env:ADMIN_NAME = 'Administrator'
$env:ADMIN_PASSWORD = '<your-strong-initial-password>'
docker compose exec -e ADMIN_EMAIL -e ADMIN_NAME -e ADMIN_PASSWORD api node src/database/seed.js
Remove-Item Env:ADMIN_PASSWORD
```

Compose runs migrations before the API and persists PostgreSQL data in a named volume. Database and API ports bind only to the local host. For Android emulator access use the local backend command (which binds to all interfaces), or configure a development-only Docker port override. Use an HTTPS reverse proxy for devices and production.

## Flutter application

The feature code, package definition, and web runner are included. Generate native platform runners using the bootstrap script below.

```powershell
cd mobile
../scripts/bootstrap-mobile.ps1
flutter pub get
flutter analyze
flutter test
# Android emulator + locally running backend:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

The existing main, pubspec, and widget test are retained by `flutter create`. Review the generated diff. Use your reverse-proxy HTTPS URL for a physical device or release build:

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://attendance.example.com/api/v1
```

The API URL must include `/api/v1`. Android requires INTERNET permission in the main manifest for release builds; see [mobile setup](docs/MOBILE.md). For local HTTP only, add a debug network-security setting as described there. Configure application IDs, signing, icons, iOS Keychain entitlements, minimum SDKs and platform permissions before distributing.

## Flutter web

Run from the mobile directory:

```powershell
flutter pub get
flutter run -d web-server --web-hostname localhost --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

Open http://localhost:8080 with the backend running. The backend CORS_ORIGINS must include this origin. Windows Application Control must allow the Flutter compiler to run.

## Tests and verification

```powershell
cd backend
npm.cmd test
# Dedicated test database; integration test creates/drops a unique temporary schema.
$env:TEST_DATABASE_URL = 'postgresql://attendance:password@localhost:5432/attendance_test'
npm.cmd test
```

Without `TEST_DATABASE_URL`, the PostgreSQL integration suite is explicitly skipped. It exercises admin login, employee creation, forbidden access, competing check-ins, checkout, history, deactivation and token revocation. HTTP tests cover input errors, anonymous access, malformed JSON, and response headers. CI provisions PostgreSQL and runs both suites, Flutter analysis/tests and an Android debug build.

**Local verification:** Backend dependencies are installed and all nine backend tests pass, including the PostgreSQL integration workflow. Database migrations and administrator login were verified. Dependency lockfiles are included. The Flutter web runner was generated, but Windows Application Control blocked dartaotruntime.exe during startup, so the frontend could not be verified. Native builds have not been verified.

## Behavior and boundaries

- One shift per employee per business date; split shifts are not supported.
- Server timestamps are authoritative. Business dates use `BUSINESS_TIMEZONE` (default `Asia/Kolkata`); instants are stored as PostgreSQL `timestamptz`.
- An overnight open shift remains available for checkout. A second shift can start after it closes. Administrators can record a missed checkout using the confirmed departure time.
- Open **Reports** as an administrator for the daily roster, including accounts without punches. Open **Calendar** for your month, or open a user’s calendar from the daily roster. Administrators can record a daily status correction with a reason, including leave or a holiday.
- Attendance uses a full-day threshold of 480 minutes and a half-day threshold of 240 minutes. A completed shift below the half-day threshold is Absent. A working day without a check-in stays Pending until the next business date, then becomes Absent. An unclosed shift from a previous day shows Missing Checkout. Sunday is the default weekly day off.
- Set `ATTENDANCE_FULL_MINUTES`, `ATTENDANCE_HALF_MINUTES`, and `ATTENDANCE_WEEKLY_OFF` in the backend environment to change the defaults. Weekly off uses ISO weekdays (Monday 1 to Sunday 7, 0 to disable). Threshold changes apply when reports are computed, including for historical dates. Run the backend migrations before using the attendance screens.
- Access tokens expire after 15 minutes. Expiry requires sign-in again. Logout, password changes, resets and employee deactivation revoke existing tokens across devices.
- Creating new administrators is supported through the protected API. The mobile creation form creates employees. Administrators cannot be deactivated using the status endpoint.
- Password recovery is an operator command, not an email flow. See deployment notes.
- No GPS, biometrics, offline attendance, leave approvals, multi-tenancy or push notifications.
- Read [API](docs/API.md), [mobile setup](docs/MOBILE.md), and [deployment requirements](docs/DEPLOYMENT.md) before release.
