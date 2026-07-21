CREATE TABLE IF NOT EXISTS `phone_calendar_events` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `author` VARCHAR(100) NOT NULL,
    `hide_author` TINYINT(1) NOT NULL DEFAULT 0,
    `title` VARCHAR(100) NOT NULL,
    `event_date` CHAR(10) NOT NULL,
    `start_time` CHAR(5) DEFAULT NULL,
    `end_time` CHAR(5) DEFAULT NULL,
    `location` VARCHAR(100) NOT NULL DEFAULT '',
    `description` TEXT,
    `image_url` TEXT DEFAULT NULL,
    `reminder_enabled` TINYINT(1) NOT NULL DEFAULT 0,
    `reminder_at` DATETIME DEFAULT NULL,
    `reminder_sent_at` DATETIME DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_event_date` (`event_date`),
    INDEX `idx_reminder_due` (`reminder_enabled`, `reminder_sent_at`, `reminder_at`)
);

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
