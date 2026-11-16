# Release and operations

Before exposing the application:

1. Run the full CI workflow, PostgreSQL integration tests, and native app builds. Perform employee/admin device acceptance tests, including expired sessions, connection failures, overnight shifts, and competing check-ins.
2. Generate and commit reviewed dependency lockfiles. Switch Docker and CI install commands to npm ci, run dependency and image vulnerability scans, and pin images/actions according to your deployment policy.
3. Use strong distinct secrets supplied by your secret manager. Set NODE_ENV=production, the organization timezone, database URL and exact web CORS origins. Never embed database credentials or JWT secrets in Flutter.
4. Put the API behind HTTPS and configure timeouts/body limits. Keep PostgreSQL private. For a remote database verify TLS with trusted CA certificates; do not disable certificate verification. The Node pg connection accepts PostgreSQL connection-string TLS options.
5. Set TRUST_PROXY=true only when traffic passes through exactly one trusted reverse proxy and clients cannot connect directly. Configure shared rate limiting at the gateway before scaling beyond one process.
6. Configure database backups/PITR and verify restore procedures, monitoring, log retention, alerting and incident response. Collect readiness, request failures and pool errors. Avoid retaining sensitive personal information unnecessarily.
7. Use a migration database role for schema changes and an application role restricted to required SELECT/INSERT/UPDATE access in a managed production database. Compose uses one role for local simplicity.
8. Finish native platform IDs, release permissions, Keychain configuration, signing, privacy disclosures and store distribution.

Migrations are ordered SQL files tracked in schema_migrations and serialized by a PostgreSQL advisory lock. Each migration runs in a transaction. Back up first and review every schema change. Never edit an already applied migration; add another file. No automatic rollback is supplied.

The initial seed command creates an administrator only when its email does not exist and never overwrites an existing account. Protect administrator credentials and remove temporary seed environment variables afterwards.

For operator-assisted password recovery, verify the account owner's identity using your organization's process, set RESET_EMAIL and RESET_PASSWORD securely in the server environment, and run from backend:
```powershell
node src/database/reset-password.js
```
This command records an operator reset event and revokes all existing sessions. Remove RESET_PASSWORD afterwards. The employee should change their temporary password immediately. There is no public password reset endpoint.

Employee creation and status changes are audited transactionally. Password resets are audited. This is not a comprehensive compliance audit system: login/security event collection, audit retention, attendance corrections and compliance requirements need organization-specific work.

The API supports graceful SIGTERM/SIGINT shutdown with a 10-second deadline. Container restart policy does not replace monitoring or an orchestrator's readiness handling. Run migrations once before starting a new API version; retain persistent database storage when replacing containers.
