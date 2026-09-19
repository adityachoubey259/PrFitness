# PrFitness Phase 9–10 Architecture

## Offline-first synchronization

Local SQLite remains the immediate source of truth.

Tracked local inserts, updates and deletes enter a persistent outbox. Existing
local data is seeded the first time a cloud account is linked. Incoming cloud
writes suppress local sync triggers while being applied, preventing echo loops.

Every synchronized record has a last acknowledged server version. The Go API
returns an explicit conflict rather than silently overwriting a newer server
record. The UI lets the user choose **Use server** or **Keep local**.

A local dataset is bound to one cloud account to reduce accidental cross-account
upload risk.

## Authentication

- Argon2id password hashing.
- Constant-time password verification.
- 15-minute JWT access tokens.
- 30-day cryptographically random refresh tokens.
- Refresh tokens stored only as SHA-256 hashes in PostgreSQL.
- Refresh-token rotation.
- Authentication request rate limiting.
- Secure token storage on the client.

## Cloud boundary

Flutter never receives PostgreSQL credentials.

Client → HTTPS → Go API → private PostgreSQL

## Backup and restore

PrFitness exports structured JSON and restores through the platform file picker.
The restore validates product format and backup version and applies local data in
a transaction. Cloud credentials are not exported or restored.

## Phase 10 release hardening

- Branded Android and Windows launcher icon.
- Native Android splash screen.
- Flutter integration-test harness.
- Release APK build.
- Release AAB build.
- Windows release build.
- Dependency review.
- Secret-safe repository rules.

Still reserved for final release-candidate work: production HTTPS/VPS deployment,
real two-device sync verification, production Play signing, real-device biometric
and notification-dialog testing, and final accessibility/performance QA.