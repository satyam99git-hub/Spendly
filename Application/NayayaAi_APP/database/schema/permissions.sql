-- =============================================================================
--  permissions
-- =============================================================================
--  Atomic capabilities, expressed as resource + action (e.g. user:delete).
--  Endpoints depend on permissions, never on role names -- that is what lets you
--  reshuffle roles without touching route code.
--
--  `name` is the denormalised "resource:action" string. It is redundant with the
--  two columns beside it, but it is the form the API and JWT scopes actually use,
--  so storing it avoids concatenating on every permission check. The UNIQUE key
--  on (resource, action) is what actually prevents duplicates.
-- =============================================================================

CREATE TABLE IF NOT EXISTS permissions (
    id              SMALLINT UNSIGNED   NOT NULL AUTO_INCREMENT,

    name            VARCHAR(100)        NOT NULL COMMENT 'Canonical form: resource:action',
    resource        VARCHAR(50)         NOT NULL COMMENT 'user, role, file, notification, ...',
    action          VARCHAR(50)         NOT NULL COMMENT 'create, read, update, delete, list, ...',
    description     VARCHAR(255)            NULL,

    is_system       BOOLEAN             NOT NULL DEFAULT FALSE
                    COMMENT 'Seeded permission; cannot be deleted',

    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE KEY uq_permissions_name (name),
    UNIQUE KEY uq_permissions_resource_action (resource, action),
    KEY idx_permissions_resource (resource)
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Atomic capabilities granted to roles';
