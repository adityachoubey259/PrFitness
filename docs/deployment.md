# PrFitness API Deployment

Required environment variables:

- `DATABASE_URL`
- `JWT_SECRET` — at least 32 random bytes
- `PORT` — optional, defaults to 8080

Apply PostgreSQL migrations in numeric order before enabling authentication or
sync traffic.

Production requirements:

1. PostgreSQL must remain private and not internet-exposed.
2. Expose the Go API only through HTTPS.
3. Store `JWT_SECRET` and database credentials outside Git.
4. Enable PostgreSQL backups and periodically test restore.
5. Monitor `/health`.
6. Do not log passwords, access tokens, refresh tokens, or private sync payloads.

The Android/Windows application remains usable offline when the server is down.