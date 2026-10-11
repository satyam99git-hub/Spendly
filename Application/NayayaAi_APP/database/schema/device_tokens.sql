-- =============================================================================
--  device_tokens
-- =============================================================================
--  FCM registration tokens -- the push delivery side of notifications.
--
--  NOTE: not in the original file list, but device_token.py was in the model
--  layer and push cannot work without it. Added for completeness.
--
--  UNIQUE on `token` alone, not (user_id, token): FCM tokens migrate between
--  accounts when two people share a device. On re-registration the service must
--  UPSERT and reassign user_id, otherwise the previous owner keeps receiving the
--  new owner's notifications.
--
--  `is_active` is cleared when FCM reports UNREGISTERED / INVALID_ARGUMENT so the
--  sender stops retrying dead tokens.
-- =============================================================================

CREATE TABLE IF NOT EXISTS device_tokens (
    id              BIGINT UNSIGNED     NOT NULL AUTO_INCREMENT,
    user_id         BIGINT UNSIGNED     NOT NULL,

    token           VARCHAR(512)        NOT NULL COMMENT 'FCM registration token',
    device_id       VARCHAR(255)            NULL COMMENT 'Stable per-install client id',
    device_name     VARCHAR(150)            NULL,
    platform        ENUM('android')     NOT NULL DEFAULT 'android'
                    COMMENT 'Phase 1 is Android only; extend the enum for iOS later',
    app_version     VARCHAR(30)             NULL,

    is_active       BOOLEAN             NOT NULL DEFAULT TRUE
                    COMMENT 'Cleared when FCM reports the token as dead',
    last_used_at    DATETIME                NULL,

    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    -- Token length exceeds the 3072-byte index limit, so key a prefix.
    UNIQUE KEY uq_device_tokens_token (token(255)),

    KEY idx_device_tokens_user_active (user_id, is_active),
    KEY idx_device_tokens_device (device_id),

    CONSTRAINT fk_device_tokens_user
        FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE CASCADE ON UPDATE CASCADE
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'FCM push registration tokens per device';
