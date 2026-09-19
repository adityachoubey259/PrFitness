# PrFitness Security Architecture

## Local-first trust model

PrFitness remains functional without a cloud account.

Primary user data is stored locally in Drift/SQLite.
Core tracking, study, reminders, routines, scoring and analytics do not
depend on an external server.

Sensitive application preferences and future authentication credentials
use platform secure storage rather than SQLite.

## Device authentication

Sensitive export creation can be protected with the device authentication
available on the host platform, including biometrics or device credentials
where supported.

The exported JSON file itself is not represented as encrypted. The current
protection controls access to creating the export.

## Backend authentication foundation

The Go API security package provides:

- Argon2id password hashing.
- Random password salts.
- Constant-time password verification.
- Signed short-lived access-token primitives.
- Explicit JWT signing-algorithm validation.
- Minimum 32-byte JWT secret requirement.

Account endpoints and cloud synchronization are intentionally deferred to
Phase 9.

## Data ownership

PrFitness provides a structured JSON export containing the user's local
profile and tracked records.

Cloud sync remains optional.

## Intended production architecture

Android / Windows application
→ local SQLite
→ authenticated HTTPS API
→ Go service
→ private PostgreSQL

The Flutter application will never connect directly to PostgreSQL.