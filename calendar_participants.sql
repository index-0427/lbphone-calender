-- 既存データを保持したまま参加予約構造だけを追加する、再実行可能な移行SQL。
-- calendar.sql で新規作成する場合、このファイルの実行は不要。
-- server/main.lua も起動時に同じ不足構造を自動検知するため、通常は手動実行不要。
CREATE TABLE IF NOT EXISTS `phone_calendar_event_participants` (
    `event_id` INT NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `participant_name` VARCHAR(100) NOT NULL,
    `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`event_id`, `citizenid`),
    INDEX `idx_participant_citizenid` (`citizenid`),
    CONSTRAINT `fk_calendar_participant_event`
        FOREIGN KEY (`event_id`) REFERENCES `phone_calendar_events` (`id`)
        ON DELETE CASCADE
);

SET @calendar_sql = IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'phone_calendar_event_participants'
          AND COLUMN_NAME = 'participant_name'
    ),
    'SELECT 1',
    'ALTER TABLE `phone_calendar_event_participants` ADD COLUMN `participant_name` VARCHAR(100) NOT NULL DEFAULT '''' AFTER `citizenid`'
);
PREPARE calendar_stmt FROM @calendar_sql;
EXECUTE calendar_stmt;
DEALLOCATE PREPARE calendar_stmt;

SET @calendar_sql = IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'phone_calendar_event_participants'
          AND COLUMN_NAME = 'joined_at'
    ),
    'SELECT 1',
    'ALTER TABLE `phone_calendar_event_participants` ADD COLUMN `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER `participant_name`'
);
PREPARE calendar_stmt FROM @calendar_sql;
EXECUTE calendar_stmt;
DEALLOCATE PREPARE calendar_stmt;

SET @calendar_sql = IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'phone_calendar_event_participants'
          AND INDEX_NAME = 'idx_participant_citizenid'
    ),
    'SELECT 1',
    'ALTER TABLE `phone_calendar_event_participants` ADD INDEX `idx_participant_citizenid` (`citizenid`)'
);
PREPARE calendar_stmt FROM @calendar_sql;
EXECUTE calendar_stmt;
DEALLOCATE PREPARE calendar_stmt;

SET @calendar_sql = IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'phone_calendar_event_participants'
          AND COLUMN_NAME = 'event_id'
          AND REFERENCED_TABLE_NAME = 'phone_calendar_events'
          AND REFERENCED_COLUMN_NAME = 'id'
    ),
    'SELECT 1',
    'ALTER TABLE `phone_calendar_event_participants` ADD CONSTRAINT `fk_calendar_participant_event` FOREIGN KEY (`event_id`) REFERENCES `phone_calendar_events` (`id`) ON DELETE CASCADE'
);
PREPARE calendar_stmt FROM @calendar_sql;
EXECUTE calendar_stmt;
DEALLOCATE PREPARE calendar_stmt;
