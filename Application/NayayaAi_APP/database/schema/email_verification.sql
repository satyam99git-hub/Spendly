-- =============================================================================
--  email_verifications
-- =============================================================================
--  Proves ownership of an address. Covers two flows with one table:
--    - signup verification  (target_email == users.email)
--    - email change         (target_email is the NEW address, not yet on users)
--
--  The address is duplicated here on purpose. During a change the users row must
--  keep the old, still-verified address until the new one is confirmed; the
--  pending value has to live somewhere, and that somewhere is `target_email`.
--
--  Both a link token and a 6-digit OTP are supported so the Android client can
--  offer either. `attempts` throttles OTP guessing -- six digits is a million
--  combinations, which is nothing without a cap. The service must refuse
--  verification once attempts exceeds its limit and force a resend.
-- =============================================================================

CREATE TABLE IF NOT EXISTS email_verifications (
    id              BIGINT UNSIGNED     NOT NULL AUTO_INCREMENT,
    user_id         BIGINT UNSIGNED     NOT NULL,

    target_email    VARCHAR(255)        NOT NULL
                    COMMENT 'Address being proven; differs from users.email on change',

    token_hash      CHAR(64)            NOT NULL COMMENT 'SHA-256 hex of the emailed link token',
    otp_code        CHAR(6)                 NULL COMMENT 'Numeric OTP alternative to the link',

    purpose         ENUM('signup', 'email_change') NOT NULL DEFAULT 'signup',

    expires_at      DATETIME            NOT NULL COMMENT 'Typically 24h for links, 10m for OTP',
    verified_at     DATETIME                NULL,
    invalidated_at  DATETIME                NULL COMMENT 'Superseded by a resend',

    attempts        SMALLINT UNSIGNED   NOT NULL DEFAULT 0
                    COMMENT 'Failed OTP submissions; lock the record past the limit',

    requested_ip    VARCHAR(45)             NULL,
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE KEY uq_email_verifications_hash (token_hash),

    KEY idx_email_verifications_user_active (user_id, verified_at, expires_at),
    KEY idx_email_verifications_expires (expires_at),
    KEY idx_email_verifications_target (target_email),

    CONSTRAINT fk_email_verifications_user
        FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE CASCADE ON UPDATE CASCADE
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Email ownership verification tokens and OTPs';
