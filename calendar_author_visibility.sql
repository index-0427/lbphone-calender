-- 既存データを保持したまま追加者名の表示設定列だけを追加する、再実行可能な移行SQL。
-- server/main.lua が起動時に不足列を自動検知するため、通常は手動実行不要。

SET @calendar_sql = IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'phone_calendar_events'
          AND COLUMN_NAME = 'hide_author'
    ),
    'SELECT 1',
    'ALTER TABLE `phone_calendar_events` ADD COLUMN `hide_author` TINYINT(1) NOT NULL DEFAULT 0 AFTER `author`'
);
PREPARE calendar_stmt FROM @calendar_sql;
EXECUTE calendar_stmt;
DEALLOCATE PREPARE calendar_stmt;
