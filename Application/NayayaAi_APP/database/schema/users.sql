-- =============================================================================
--  users
-- =============================================================================
--  The account record. Supports both local (email + bcrypt) and Google OAuth
--  sign-in against a single row, so a user who registers with a password and
--  later taps "Continue with Google" is linked, not duplicated.
--
--  KEY DECISIONS
--
--  1. Dual identifier: `id` (BIGINT, internal) + `public_id` (UUID, external).
--     Every FK in the database points at `id` -- narrow, sequential, and kind to
--     InnoDB's clustered index. Only `public_id` is ever emitted by the API, so
--     the Android client cannot enumerate accounts by incrementing an integer.
--     If you would rather not carry both, drop public_id and expose `id`; it is
--     a one-line change now and a painful migration later.
--
--  2. `password_hash` is NULLable. A Google-only user has no password. The CHECK
--     below enforces that local accounts always do.
--
--  3. `password_changed_at` is the token-invalidation cutoff. JWTs issued before
--     this timestamp must be rejected, which is how "change password logs out
--     other devices" works without a token blacklist.
--
--  4. Soft delete via `deleted_at`. Because `email` is UNIQUE, the service layer
--     MUST anonymise the address on delete (e.g. "deleted+<public_id>@invalid")
--     or the address stays permanently unusable for re-registration.
--
--  5. All DATETIMEs are UTC. MySQL DATETIME carries no timezone; the application
--     is the only thing enforcing this, so never write local time.
-- =============================================================================

CREATE TABLE IF NOT EXISTS users (
    id                      BIGINT UNSIGNED     NOT NULL AUTO_INCREMENT,
    public_id               CHAR(36)            NOT NULL
                            COMMENT 'UUIDv4 exposed by the API; never expose id',

    -- ---- identity -----------------------------------------------------------
    email                   VARCHAR(255)        NOT NULL
                            COMMENT 'Stored lowercase; normalise in the service layer',
    password_hash           VARCHAR(255)            NULL
                            COMMENT 'bcrypt (60 chars); NULL for OAuth-only accounts',

    -- ---- profile ------------------------------------------------------------
    full_name               VARCHAR(150)        NOT NULL,
    phone                   VARCHAR(20)             NULL,
    avatar_url              VARCHAR(512)            NULL,
    date_of_birth           DATE                    NULL,
    bio                     VARCHAR(500)            NULL,

    -- ---- auth provider ------------------------------------------------------
    auth_provider           ENUM('local', 'google') NOT NULL DEFAULT 'local',
    google_id               VARCHAR(255)            NULL
                            COMMENT 'Google "sub" claim; UNIQUE tolerates many NULLs',

    -- ---- verification / status ----------------------------------------------
    is_email_verified       BOOLEAN             NOT NULL DEFAULT FALSE,
    email_verified_at       DATETIME                NULL,
    is_active               BOOLEAN             NOT NULL DEFAULT TRUE
                            COMMENT 'FALSE = disabled by an admin; blocks login',

    -- ---- security telemetry -------------------------------------------------
    last_login_at           DATETIME                NULL,
    last_login_ip           VARCHAR(45)             NULL COMMENT 'IPv4 or IPv6 text form',
    failed_login_attempts   SMALLINT UNSIGNED   NOT NULL DEFAULT 0,
    locked_until            DATETIME                NULL
                            COMMENT 'Set on repeated failures; login refused until passed',
    password_changed_at     DATETIME                NULL
                            COMMENT 'Reject access tokens issued before this instant',

    -- ---- audit --------------------------------------------------------------
    created_at              DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
                                                ON UPDATE CURRENT_TIMESTAMP,
    deleted_at              DATETIME                NULL COMMENT 'Soft delete marker',

    PRIMARY KEY (id),
    UNIQUE KEY uq_users_public_id (public_id),
    UNIQUE KEY uq_users_email (email),
    UNIQUE KEY uq_users_google_id (google_id),

    KEY idx_users_active (is_active, deleted_at),
    KEY idx_users_created_at (created_at),
    KEY idx_users_deleted_at (deleted_at),

    -- A local account is unusable without a password hash.
    CONSTRAINT chk_users_local_has_password
        CHECK (auth_provider <> 'local' OR password_hash IS NOT NULL),

    -- A Google account is unusable without the provider subject id.
    CONSTRAINT chk_users_google_has_subject
        CHECK (auth_provider <> 'google' OR google_id IS NOT NULL)
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'User accounts for local and Google authentication';
