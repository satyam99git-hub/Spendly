-- =============================================================================
--  role_permissions   (join: roles <-> permissions)
-- =============================================================================
--  NOTE: this table was not in the original file list, but roles and permissions
--  are meaningless without the mapping between them. Added for completeness.
--
--  Composite PK (role_id, permission_id) doubles as the uniqueness constraint and
--  as the covering index for "what can this role do" -- the direction the auth
--  layer reads on every request. The secondary key on permission_id serves the
--  reverse question ("who holds this permission") for the admin screens.
--
--  Both FKs CASCADE: deleting a role or permission should not leave orphan rows.
--  Seeded rows are protected upstream by roles.is_system / permissions.is_system.
-- =============================================================================

CREATE TABLE IF NOT EXISTS role_permissions (
    role_id         SMALLINT UNSIGNED   NOT NULL,
    permission_id   SMALLINT UNSIGNED   NOT NULL,

    granted_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (role_id, permission_id),
    KEY idx_role_permissions_permission (permission_id),

    CONSTRAINT fk_role_permissions_role
        FOREIGN KEY (role_id) REFERENCES roles (id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_role_permissions_permission
        FOREIGN KEY (permission_id) REFERENCES permissions (id)
        ON DELETE CASCADE ON UPDATE CASCADE
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Which permissions each role grants';
