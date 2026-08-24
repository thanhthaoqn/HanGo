-- Run before deploying the backend that persists agreement metadata.
-- Safe to run more than once on MySQL.

SET @add_agreement_version_sql = IF(
    EXISTS(
        SELECT 1
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'trainer_profiles'
          AND COLUMN_NAME = 'agreement_version'
    ),
    'SELECT 1',
    'ALTER TABLE `trainer_profiles` ADD COLUMN `agreement_version` VARCHAR(50) NULL'
);
PREPARE add_agreement_version_stmt FROM @add_agreement_version_sql;
EXECUTE add_agreement_version_stmt;
DEALLOCATE PREPARE add_agreement_version_stmt;

SET @add_agreement_accepted_at_sql = IF(
    EXISTS(
        SELECT 1
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'trainer_profiles'
          AND COLUMN_NAME = 'agreement_accepted_at'
    ),
    'SELECT 1',
    'ALTER TABLE `trainer_profiles` ADD COLUMN `agreement_accepted_at` DATETIME(6) NULL'
);
PREPARE add_agreement_accepted_at_stmt FROM @add_agreement_accepted_at_sql;
EXECUTE add_agreement_accepted_at_stmt;
DEALLOCATE PREPARE add_agreement_accepted_at_stmt;

-- Existing accepted agreements predate version tracking; preserve that fact explicitly.
UPDATE `trainer_profiles`
SET `agreement_version` = COALESCE(`agreement_version`, 'legacy-before-20260823'),
    `agreement_accepted_at` = COALESCE(`agreement_accepted_at`, CURRENT_TIMESTAMP(6))
WHERE `agreement_signed` = TRUE;
