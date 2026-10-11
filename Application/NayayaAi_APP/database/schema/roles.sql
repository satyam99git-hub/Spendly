-- =============================================================================
--  roles
-- =============================================================================
--  Coarse-grained authorization buckets assigned to users (admin / user).
--  Kept deliberately small: fine-grained rules live in `permissions`, and roles
--  are just named bundles of them. That way adding a capability never requires
--  a new role, and `RoleChecker(["admin"])` stays a cheap dependency.
--
--  SMALLINT PK: this table holds tens of rows, not millions. A narrow key keeps
--  the user_roles / role_permissions join tables compact.
--
--  is_system: guards seeded roles ('admin', 'user') from deletion via the admin
--  API. The service layer must refuse DELETE when is_system = TRUE.
-- =============================================================================

CREATE TABLE IF NOT EXISTS roles (
    id              SMALLINT UNSIGNED   NOT NULL AUTO_INCREMENT,

    name            VARCHAR(50)         NOT NULL COMMENT 'Machine name, lowercase: admin, user',
    display_name    VARCHAR(100)        NOT NULL COMMENT 'Human label for admin UI',
    description     VARCHAR(255)            NULL,

    is_system       BOOLEAN             NOT NULL DEFAULT FALSE
                    COMMENT 'Seeded role; cannot be deleted or renamed',

    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE KEY uq_roles_name (name)
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Role definitions for RBAC';
