-- =============================================================================
--  audit_logs
-- =============================================================================
--  Append-only record of security-relevant events: logins (success and failure),
--  password changes, role grants, admin actions, token reuse detection.
--
--  THE COLUMN IS `details`, NOT `metadata`. SQLAlchemy's declarative base already
--  owns `metadata` as a class attribute -- naming the column that collides at
--  import time. Cheap to avoid now, confusing to debug later.
--
--  user_id is nullable and ON DELETE SET NULL: failed logins for a non-existent
--  address have no user, and an account deletion must not erase its own audit
--  trail. `actor_email` preserves the address as typed, even when no row matched.
--
--  This table only grows. Partition by created_at or ship to cold storage before
--  it becomes the largest thing in the database.
-- =============================================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id              BIGINT UNSIGNED     NOT NULL AUTO_INCREMENT,

    user_id         BIGINT UNSIGNED         NULL COMMENT 'NULL when no account matched',
    actor_email     VARCHAR(255)            NULL COMMENT 'Address as submitted, always kept',

    action          VARCHAR(100)        NOT NULL
                    COMMENT 'auth.login, auth.login_failed, user.role_granted, ...',
    entity_type     VARCHAR(50)             NULL COMMENT 'user, role, file, ...',
    entity_id       VARCHAR(64)             NULL COMMENT 'Public id of the affected row',

    status          ENUM('success', 'failure') NOT NULL,
    message         VARCHAR(500)            NULL,
    details         JSON                    NULL COMMENT 'Changed fields, reason codes, ...',

    ip_address      VARCHAR(45)             NULL,
    user_agent      VARCHAR(512)            NULL,
    request_id      CHAR(36)                NULL
                    COMMENT 'Correlates with the API access log',

    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    KEY idx_audit_logs_user_created (user_id, created_at),
    KEY idx_audit_logs_action_created (action, created_at),
    KEY idx_audit_logs_created (created_at),
    -- Brute-force detection: failures from one address in a window.
    KEY idx_audit_logs_ip_created (ip_address, created_at),
    KEY idx_audit_logs_request (request_id),

    CONSTRAINT fk_audit_logs_user
        FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE SET NULL ON UPDATE CASCADE
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Append-only security and administrative audit trail';
