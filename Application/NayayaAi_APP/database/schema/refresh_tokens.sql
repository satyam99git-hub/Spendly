-- =============================================================================
--  refresh_tokens
-- =============================================================================
--  Long-lived tokens the Android client exchanges for fresh access tokens. This
--  is the most security-sensitive table in the schema; three things matter.
--
--  1. ONLY THE HASH IS STORED. `token_hash` is SHA-256 hex of the raw token. A
--     database leak therefore does not hand out live sessions. Never add a column
--     holding the raw value. (SHA-256, not bcrypt: these are 256-bit random
--     strings, not human passwords, so there is nothing to brute-force and the
--     lookup has to be fast on every refresh.)
--
--  2. ROTATION WITH REUSE DETECTION. Every refresh issues a new row and revokes
--     the old one, linked by `family_id`. If a token that is already revoked is
--     presented, it was replayed -- the service must revoke the entire family and
--     force re-login. `parent_id` preserves the chain for forensics.
--
--  3. REVOCATION IS EXPLICIT, NOT DELETION. Rows are kept with `revoked_at` set
--     so reuse detection still has something to match against. The scheduled
--     cleanup procedure prunes them well after expiry.
--
--  Device columns power the "active sessions" screen and per-device logout.
-- =============================================================================

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id              BIGINT UNSIGNED     NOT NULL AUTO_INCREMENT,
    user_id         BIGINT UNSIGNED     NOT NULL,

    token_hash      CHAR(64)            NOT NULL COMMENT 'SHA-256 hex of the raw token',
    family_id       CHAR(36)            NOT NULL
                    COMMENT 'Shared by every token in one rotation lineage',
    parent_id       BIGINT UNSIGNED         NULL
                    COMMENT 'Token this one replaced; NULL for the first in a family',

    expires_at      DATETIME            NOT NULL,
    revoked_at      DATETIME                NULL,
    revoked_reason  ENUM('logout', 'rotated', 'reuse_detected',
                         'password_changed', 'admin_revoked', 'expired') NULL,

    -- ---- device / session context -------------------------------------------
    device_id       VARCHAR(255)            NULL COMMENT 'Stable per-install client id',
    device_name     VARCHAR(150)            NULL COMMENT 'e.g. "Pixel 8 Pro"',
    user_agent      VARCHAR(512)            NULL,
    ip_address      VARCHAR(45)             NULL,

    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_used_at    DATETIME                NULL,

    PRIMARY KEY (id),
    UNIQUE KEY uq_refresh_tokens_hash (token_hash),

    -- The hot path: "find this user's live tokens".
    KEY idx_refresh_tokens_user_active (user_id, revoked_at, expires_at),
    -- Reuse detection walks the family.
    KEY idx_refresh_tokens_family (family_id),
    -- Cleanup job scans by expiry.
    KEY idx_refresh_tokens_expires (expires_at),
    KEY idx_refresh_tokens_device (user_id, device_id),
    KEY idx_refresh_tokens_parent (parent_id),

    CONSTRAINT fk_refresh_tokens_user
        FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    -- Self-reference: keep the chain intact if an ancestor is pruned.
    CONSTRAINT fk_refresh_tokens_parent
        FOREIGN KEY (parent_id) REFERENCES refresh_tokens (id)
        ON DELETE SET NULL ON UPDATE CASCADE
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Rotating refresh tokens with reuse detection';
