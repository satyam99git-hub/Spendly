-- =============================================================================
--  notifications
-- =============================================================================
--  In-app notification feed. Distinct from push delivery: a row here is what the
--  user sees in the notifications screen and survives a missed push.
--
--  `payload` is JSON rather than a set of columns because notification types
--  carry different data (a deep-link route, an entity id, a thumbnail). Keeping
--  it schemaless avoids a migration per new type. MySQL 8 can index into it via
--  a generated column if a specific key ever needs querying.
--
--  The composite index is ordered (user_id, is_read, created_at DESC) to match
--  the only query that matters at scale -- "this user's unread, newest first" --
--  and to serve the unread badge count from the index alone.
-- =============================================================================

CREATE TABLE IF NOT EXISTS notifications (
    id              BIGINT UNSIGNED     NOT NULL AUTO_INCREMENT,
    public_id       CHAR(36)            NOT NULL,

    user_id         BIGINT UNSIGNED     NOT NULL,

    type            VARCHAR(50)         NOT NULL
                    COMMENT 'system, security_alert, account, message, ...',
    title           VARCHAR(255)        NOT NULL,
    body            TEXT                NOT NULL,
    image_url       VARCHAR(512)            NULL,

    payload         JSON                    NULL
                    COMMENT 'Type-specific data: deep link route, entity ids, ...',

    is_read         BOOLEAN             NOT NULL DEFAULT FALSE,
    read_at         DATETIME                NULL,

    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at      DATETIME                NULL,

    PRIMARY KEY (id),
    UNIQUE KEY uq_notifications_public_id (public_id),

    KEY idx_notifications_user_feed (user_id, is_read, created_at),
    KEY idx_notifications_user_created (user_id, created_at),
    KEY idx_notifications_deleted (deleted_at),

    CONSTRAINT fk_notifications_user
        FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE CASCADE ON UPDATE CASCADE
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'In-app notification feed per user';
