BEGIN;

CREATE TABLE IF NOT EXISTS prfitness.study_sessions (
    id UUID PRIMARY KEY,

    user_id UUID NOT NULL
        REFERENCES prfitness.users(id)
        ON DELETE CASCADE,

    subject TEXT NOT NULL,

    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ NOT NULL,

    duration_seconds INTEGER NOT NULL
        CHECK (duration_seconds > 0),

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW(),

    CHECK (ended_at > started_at)
);

CREATE INDEX IF NOT EXISTS
    idx_prfitness_study_user_started
ON prfitness.study_sessions(
    user_id,
    started_at DESC
);

CREATE TABLE IF NOT EXISTS prfitness.goals (
    id UUID PRIMARY KEY,

    user_id UUID NOT NULL
        REFERENCES prfitness.users(id)
        ON DELETE CASCADE,

    title TEXT NOT NULL,

    category TEXT NOT NULL,

    frequency TEXT NOT NULL
        DEFAULT 'daily',

    active BOOLEAN NOT NULL
        DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS
    idx_prfitness_goals_user
ON prfitness.goals(
    user_id,
    active
);

CREATE TABLE IF NOT EXISTS prfitness.goal_completions (
    id UUID PRIMARY KEY,

    goal_id UUID NOT NULL
        REFERENCES prfitness.goals(id)
        ON DELETE CASCADE,

    completed_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS
    idx_prfitness_goal_completion
ON prfitness.goal_completions(
    goal_id,
    completed_at DESC
);

CREATE TABLE IF NOT EXISTS prfitness.routine_items (
    id UUID PRIMARY KEY,

    user_id UUID NOT NULL
        REFERENCES prfitness.users(id)
        ON DELETE CASCADE,

    title TEXT NOT NULL,

    routine_type TEXT NOT NULL,

    sort_order INTEGER NOT NULL
        DEFAULT 0,

    active BOOLEAN NOT NULL
        DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS
    idx_prfitness_routines_user
ON prfitness.routine_items(
    user_id,
    active,
    sort_order
);

CREATE TABLE IF NOT EXISTS prfitness.routine_completions (
    id UUID PRIMARY KEY,

    routine_id UUID NOT NULL
        REFERENCES prfitness.routine_items(id)
        ON DELETE CASCADE,

    completed_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS
    idx_prfitness_routine_completion
ON prfitness.routine_completions(
    routine_id,
    completed_at DESC
);

COMMIT;