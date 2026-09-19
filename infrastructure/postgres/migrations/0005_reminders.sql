BEGIN;

CREATE TABLE IF NOT EXISTS prfitness.reminders (
    id UUID PRIMARY KEY,

    user_id UUID NOT NULL
        REFERENCES prfitness.users(id)
        ON DELETE CASCADE,

    title TEXT NOT NULL,
    body TEXT NOT NULL,

    category TEXT NOT NULL,

    schedule_type TEXT NOT NULL
        CHECK (
            schedule_type IN (
                'daily',
                'weekdays',
                'one_time'
            )
        ),

    hour INTEGER NOT NULL
        CHECK (hour BETWEEN 0 AND 23),

    minute INTEGER NOT NULL
        CHECK (minute BETWEEN 0 AND 59),

    weekdays_mask INTEGER NOT NULL
        DEFAULT 127,

    scheduled_at TIMESTAMPTZ NULL,

    enabled BOOLEAN NOT NULL
        DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS
    idx_prfitness_reminders_user_enabled
ON prfitness.reminders(
    user_id,
    enabled
);

COMMIT;