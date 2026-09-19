BEGIN;

CREATE TABLE IF NOT EXISTS prfitness.food_entries (
    id UUID PRIMARY KEY,

    user_id UUID NOT NULL
        REFERENCES prfitness.users(id)
        ON DELETE CASCADE,

    name TEXT NOT NULL,

    calories DOUBLE PRECISION NOT NULL
        CHECK (calories >= 0),

    protein_g DOUBLE PRECISION NULL,
    carbs_g DOUBLE PRECISION NULL,
    fat_g DOUBLE PRECISION NULL,

    occurred_at TIMESTAMPTZ NOT NULL,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS
    idx_prfitness_food_user_time
ON prfitness.food_entries(
    user_id,
    occurred_at DESC
);

CREATE TABLE IF NOT EXISTS prfitness.activity_entries (
    id UUID PRIMARY KEY,

    user_id UUID NOT NULL
        REFERENCES prfitness.users(id)
        ON DELETE CASCADE,

    activity_type TEXT NOT NULL,
    intensity TEXT NOT NULL,

    duration_minutes INTEGER NOT NULL
        CHECK (duration_minutes > 0),

    distance_km DOUBLE PRECISION NULL
        CHECK (
            distance_km IS NULL
            OR distance_km >= 0
        ),

    calories_burned DOUBLE PRECISION NOT NULL
        CHECK (calories_burned >= 0),

    occurred_at TIMESTAMPTZ NOT NULL,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS
    idx_prfitness_activity_user_time
ON prfitness.activity_entries(
    user_id,
    occurred_at DESC
);

CREATE TABLE IF NOT EXISTS prfitness.water_entries (
    id UUID PRIMARY KEY,

    user_id UUID NOT NULL
        REFERENCES prfitness.users(id)
        ON DELETE CASCADE,

    amount_ml INTEGER NOT NULL
        CHECK (amount_ml > 0),

    occurred_at TIMESTAMPTZ NOT NULL,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS
    idx_prfitness_water_user_time
ON prfitness.water_entries(
    user_id,
    occurred_at DESC
);

COMMIT;