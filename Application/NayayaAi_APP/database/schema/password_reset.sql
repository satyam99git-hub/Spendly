-- =============================================================================
--  password_resets
-- =============================================================================
--  Single-use, time-boxed tokens backing the "forgot password" flow.
--
--  Same hashing rule as refresh_tokens: the raw token goes in the email link and
--  nowhere else. Anyone reading this table cannot reset anyone's password.
--
--  `used_at` (not deletion) marks consumption, so a replayed link can be told
--  apart from an expired one and logged as a distinct security event.
--
--  On successful reset the service must, in one transaction:
--    - update users.password_hash and users.password_changed_at
--    - stamp used_at here
--    - revoke every refresh_tokens row for that user ('password_changed')
--  Anything less leaves an attacker's existing session alive.
-- =============================================================================

CREATE TABLE IF NOT EXISTS password_resets (
    id              BIGINT UNSIGNED     NOT NULL AUTO_INCREMENT,
    user_id         BIGINT UNSIGNED     NOT NULL,

    token_hash      CHAR(64)            NOT NULL COMMENT 'SHA-256 hex of the emailed token',

    expires_at      DATETIME            NOT NULL COMMENT 'Short TTL; 15-60 minutes',
    used_at         DATETIME                NULL COMMENT 'Set on successful reset',
    invalidated_at  DATETIME                NULL
                    COMMENT 'Superseded by a newer request, or revoked by an admin',

    -- ---- request context (rate limiting + abuse investigation) ---------------
    requested_ip    VARCHAR(45)             NULL,
    requested_agent VARCHAR(512)            NULL,

    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE KEY uq_password_resets_hash (token_hash),

    KEY idx_password_resets_user_active (user_id, used_at, expires_at),
    KEY idx_password_resets_expires (expires_at),
    -- Throttles "how many resets has this address requested lately".
    KEY idx_password_resets_ip_created (requested_ip, created_at),

    CONSTRAINT fk_password_resets_user
        FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE CASCADE ON UPDATE CASCADE
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Single-use password reset tokens';
