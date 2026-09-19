BEGIN;

CREATE TABLE IF NOT EXISTS prfitness.profiles (
    user_id UUID PRIMARY KEY
        REFERENCES prfitness.users(id)
        ON DELETE CASCADE,

    name TEXT NOT NULL,
    birth_date DATE NOT NULL,

    sex TEXT NOT NULL
        CHECK (sex IN ('male', 'female')),

    height_cm DOUBLE PRECISION NOT NULL
        CHECK (height_cm > 0),

    weight_kg DOUBLE PRECISION NOT NULL
        CHECK (weight_kg > 0),

    target_weight_kg DOUBLE PRECISION NULL
        CHECK (
            target_weight_kg IS NULL
            OR target_weight_kg > 0
        ),

    activity_level TEXT NOT NULL,

    goal TEXT NOT NULL,

    daily_study_target_minutes INTEGER NOT NULL
        DEFAULT 120,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW()
);

COMMIT;