-- 既存データを保持したままリマインダー構造だけを追加する、再実行可能な移行SQL。
-- server/main.lua も起動時に同じ不足構造を自動検知するため、通常は手動実行不要。

SET @calendar_sql = IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'phone_calendar_events'
          AND COLUMN_NAME = 'reminder_enabled'
    ),
    'SELECT 1',
    'ALTER TABLE `phone_calendar_events` ADD COLUMN `reminder_enabled` TINYINT(1) NOT NULL DEFAULT 0 AFTER `description`'
);
PREPARE calendar_stmt FROM @calendar_sql;
EXECUTE calendar_stmt;
DEALLOCATE PREPARE calendar_stmt;

SET @calendar_sql = IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'phone_calendar_events'
          AND COLUMN_NAME = 'reminder_at'
    ),
    'SELECT 1',
    'ALTER TABLE `phone_calendar_events` ADD COLUMN `reminder_at` DATETIME DEFAULT NULL AFTER `reminder_enabled`'
);
PREPARE calendar_stmt FROM @calendar_sql;
EXECUTE calendar_stmt;
DEALLOCATE PREPARE calendar_stmt;

SET @calendar_sql = IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'phone_calendar_events'
          AND COLUMN_NAME = 'reminder_sent_at'
    ),
    'SELECT 1',
    'ALTER TABLE `phone_calendar_events` ADD COLUMN `reminder_sent_at` DATETIME DEFAULT NULL AFTER `reminder_at`'
);
PREPARE calendar_stmt FROM @calendar_sql;
EXECUTE calendar_stmt;
DEALLOCATE PREPARE calendar_stmt;

SET @calendar_sql = IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'phone_calendar_events'
          AND INDEX_NAME = 'idx_reminder_due'
    ),
    'SELECT 1',
    'ALTER TABLE `phone_calendar_events` ADD INDEX `idx_reminder_due` (`reminder_enabled`, `reminder_sent_at`, `reminder_at`)'
);
PREPARE calendar_stmt FROM @calendar_sql;
EXECUTE calendar_stmt;
DEALLOCATE PREPARE calendar_stmt;
