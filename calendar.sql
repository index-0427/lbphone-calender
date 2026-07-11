CREATE TABLE IF NOT EXISTS `phone_calendar_events` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `author` VARCHAR(100) NOT NULL,
    `title` VARCHAR(100) NOT NULL,
    `event_date` CHAR(10) NOT NULL,
    `start_time` CHAR(5) DEFAULT NULL,
    `end_time` CHAR(5) DEFAULT NULL,
    `location` VARCHAR(100) NOT NULL DEFAULT '',
    `description` TEXT,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_event_date` (`event_date`)
);
