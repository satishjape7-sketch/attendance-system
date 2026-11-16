# API v1

Base path: `/api/v1`. JSON requests and responses. Protected endpoints require `Authorization: Bearer <token>`.

Success: `{"data": ...}`. Errors: `{"error":{"code":"...","message":"..."}}`. Validation errors include field details. Lists return `data`, `page`, and `hasMore`; default limit 30, maximum 100. No password hashes are returned.

| Method | Path | Access | Request / purpose |
|---|---|---|---|
| POST | /auth/login | Public | email, password; returns token and user |
| GET | /auth/me | Signed in | Current user |
| POST | /auth/logout | Signed in | Revoke all user sessions; 204 |
| POST | /auth/password | Signed in | currentPassword, newPassword; revoke all sessions; 204 |
| GET | /attendance/today | Signed in | Current business-day record or previous open shift, nullable |
| POST | /attendance/check-in | Signed in | No body; 201 or 409 |
| POST | /attendance/check-out | Signed in | Close open shift; 200 or 409 |
| GET | /attendance/history | Signed in | Own records; from, to, page, limit |
| GET | /attendance/report | Admin | Team records including name/email; from, to, page, limit |
| GET | /users | Admin | Users; page, limit |
| POST | /users | Admin | name, email, password, role (employee default); 201 |
| PATCH | /users/:id/status | Admin | active boolean; employees only |
| GET | /health/live | Public, outside base path | Process health |
| GET | /health/ready | Public, outside base path | Database readiness |

Dates use YYYY-MM-DD, inclusive. Invalid dates, reversed ranges, and oversized pages return 400. Attendance rows contain id, user_id, work_date, check_in, check_out. Instants are ISO 8601; work_date is a calendar date.

Example login:
```json
{"email":"employee@example.com","password":"a-strong-password"}
```

Passwords: 12+ characters and <=72 UTF-8 bytes on creation/change/reset. Login deliberately returns the same message for unknown users, wrong passwords and inactive accounts. Per-process rate limits: 10 login attempts per IP per 15 minutes; 120 API requests per IP per minute. Rate limits return JSON with 429. For multiple replicas use a shared rate-limit store or upstream enforcement.

Typical statuses: 400 invalid input; 401 invalid/expired session; 403 forbidden; 404 missing route/employee; 409 duplicate attendance/email or no open shift; 413 oversized JSON; 429 rate limit; 500 internal error with request ID.
