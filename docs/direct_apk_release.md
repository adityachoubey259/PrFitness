# PrFitness Direct Release

PrFitness is distributed directly as an Android APK and Windows application.

## Production endpoint

https://prfitness.itltech.in

## Architecture

Android / Windows
→ local SQLite
→ HTTPS
→ Nginx
→ Go API
→ private PostgreSQL

## Android distribution

Google Play is not required.

Customer and onsite releases use the signed release APK.

The permanent Android signing key is deliberately stored outside Git. Future
APK versions must use the same signing identity so Android can install them as
updates.

Every distributed APK must have a SHA-256 checksum.

## Security

- No PostgreSQL credentials are embedded in clients.
- Remote non-HTTPS API URLs are rejected.
- Authentication tokens use platform secure storage.
- Passwords are protected server-side with Argon2id.
- Refresh tokens are hashed and rotated.
- Production enforces a maximum of two active devices.
- PostgreSQL is private.
- Go API listens behind Nginx.
- Automated PostgreSQL backups and tested restore are enabled.

## Release build

Android:

flutter build apk --release --dart-define=PRFITNESS_API_BASE_URL=https://prfitness.itltech.in

Windows:

flutter build windows --release --dart-define=PRFITNESS_API_BASE_URL=https://prfitness.itltech.in