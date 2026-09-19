BEGIN;

CREATE TABLE IF NOT EXISTS prfitness.accounts (
    id UUID PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS prfitness.refresh_tokens (
    id UUID PRIMARY KEY,
    account_id UUID NOT NULL
        REFERENCES prfitness.accounts(id)
        ON DELETE CASCADE,
    token_hash BYTEA NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS idx_prfitness_refresh_account
ON prfitness.refresh_tokens(account_id, expires_at DESC);

CREATE SEQUENCE IF NOT EXISTS prfitness.sync_version_seq
AS BIGINT START WITH 1;

CREATE TABLE IF NOT EXISTS prfitness.sync_records (
    account_id UUID NOT NULL
        REFERENCES prfitness.accounts(id)
        ON DELETE CASCADE,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    payload JSONB NULL,
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    server_version BIGINT NOT NULL
        DEFAULT nextval('prfitness.sync_version_seq'),
    PRIMARY KEY (account_id, entity_type, entity_id)
);

CREATE INDEX IF NOT EXISTS idx_prfitness_sync_pull
ON prfitness.sync_records(account_id, server_version);

COMMIT;