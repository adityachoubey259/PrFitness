BEGIN;

CREATE INDEX IF NOT EXISTS
    idx_prfitness_food_analytics
ON prfitness.food_entries(
    user_id,
    occurred_at DESC
);

CREATE INDEX IF NOT EXISTS
    idx_prfitness_activity_analytics
ON prfitness.activity_entries(
    user_id,
    occurred_at DESC
);

CREATE INDEX IF NOT EXISTS
    idx_prfitness_water_analytics
ON prfitness.water_entries(
    user_id,
    occurred_at DESC
);

CREATE INDEX IF NOT EXISTS
    idx_prfitness_study_analytics
ON prfitness.study_sessions(
    user_id,
    started_at DESC
);

CREATE INDEX IF NOT EXISTS
    idx_prfitness_goal_completion_time
ON prfitness.goal_completions(
    completed_at DESC
);

CREATE INDEX IF NOT EXISTS
    idx_prfitness_routine_completion_time
ON prfitness.routine_completions(
    completed_at DESC
);

COMMIT;