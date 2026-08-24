-- Run only after the new backend is deployed and verified healthy.
-- This removes columns that are no longer mapped by backend or frontend code.

SET @drop_experience_sql = IF(
    EXISTS(
        SELECT 1
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'trainer_profiles'
          AND COLUMN_NAME = 'experience'
    ),
    'ALTER TABLE `trainer_profiles` DROP COLUMN `experience`',
    'SELECT 1'
);
PREPARE drop_experience_stmt FROM @drop_experience_sql;
EXECUTE drop_experience_stmt;
DEALLOCATE PREPARE drop_experience_stmt;

SET @drop_workplace_sql = IF(
    EXISTS(
        SELECT 1
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'trainer_profiles'
          AND COLUMN_NAME = 'workplace'
    ),
    'ALTER TABLE `trainer_profiles` DROP COLUMN `workplace`',
    'SELECT 1'
);
PREPARE drop_workplace_stmt FROM @drop_workplace_sql;
EXECUTE drop_workplace_stmt;
DEALLOCATE PREPARE drop_workplace_stmt;
