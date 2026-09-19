BEGIN;

CREATE SCHEMA IF NOT EXISTS prfitness;

CREATE TABLE IF NOT EXISTS prfitness.users (
    id UUID PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ NULL
);

CREATE TABLE IF NOT EXISTS prfitness.devices (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL
        REFERENCES prfitness.users(id)
        ON DELETE CASCADE,
    device_name TEXT NOT NULL,
    platform TEXT NOT NULL,
    app_version TEXT NULL,
    last_sync_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_devices_user_id
    ON prfitness.devices(user_id);

COMMIT;
