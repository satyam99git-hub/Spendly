-- =============================================================================
--  user_roles   (join: users <-> roles)
-- =============================================================================
--  Many-to-many so an account can hold several roles at once. Registration seeds
--  exactly one row here ('user'); promotion to admin adds a second rather than
--  overwriting, which keeps the audit trail honest.
--
--  assigned_by is ON DELETE SET NULL, not CASCADE: if the admin who granted a
--  role is later deleted, the grant itself must survive. That is the whole point
--  of recording it.
-- =============================================================================

CREATE TABLE IF NOT EXISTS user_roles (
    user_id         BIGINT UNSIGNED     NOT NULL,
    role_id         SMALLINT UNSIGNED   NOT NULL,

    assigned_at     DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assigned_by     BIGINT UNSIGNED         NULL
                    COMMENT 'Admin who granted this role; NULL if system-assigned',

    PRIMARY KEY (user_id, role_id),
    KEY idx_user_roles_role (role_id),
    KEY idx_user_roles_assigned_by (assigned_by),

    CONSTRAINT fk_user_roles_user
        FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_user_roles_role
        FOREIGN KEY (role_id) REFERENCES roles (id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_user_roles_assigned_by
        FOREIGN KEY (assigned_by) REFERENCES users (id)
        ON DELETE SET NULL ON UPDATE CASCADE
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Role assignments per user';
