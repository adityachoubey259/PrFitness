BEGIN;

ALTER TABLE prfitness.refresh_tokens
ADD COLUMN IF NOT EXISTS device_id TEXT NOT NULL DEFAULT 'legacy';

UPDATE prfitness.refresh_tokens
SET device_id = id::text
WHERE device_id = 'legacy';

WITH ranked AS (
    SELECT
        id,
        ROW_NUMBER() OVER (
            PARTITION BY account_id
            ORDER BY created_at DESC
        ) AS position
    FROM prfitness.refresh_tokens
    WHERE revoked_at IS NULL
      AND expires_at > NOW()
)
UPDATE prfitness.refresh_tokens
SET revoked_at = NOW()
WHERE id IN (
    SELECT id
    FROM ranked
    WHERE position > 2
);

CREATE INDEX IF NOT EXISTS idx_prfitness_refresh_active_device
ON prfitness.refresh_tokens(account_id, device_id, expires_at DESC)
WHERE revoked_at IS NULL;

COMMIT;