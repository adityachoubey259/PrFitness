BEGIN;

CREATE TABLE IF NOT EXISTS prfitness.weight_entries (
    id UUID PRIMARY KEY,

    user_id UUID NOT NULL
        REFERENCES prfitness.users(id)
        ON DELETE CASCADE,

    weight_kg DOUBLE PRECISION NOT NULL
        CHECK (
            weight_kg >= 25
            AND weight_kg <= 400
        ),

    note TEXT NULL,

    occurred_at TIMESTAMPTZ NOT NULL,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS
    idx_prfitness_weight_user_time
ON prfitness.weight_entries(
    user_id,
    occurred_at DESC
);

COMMIT;