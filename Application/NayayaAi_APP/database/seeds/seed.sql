-- =============================================================================
--  NayayaAi -- seed data orchestrator
-- =============================================================================
--  Populates the reference data the application cannot boot without: roles, the
--  permission catalogue, the grants between them, and one bootstrap administrator.
--
--  USAGE (run from this directory -- SOURCE paths are relative to the CWD):
--
--      cd database/seeds
--      mysql -u root -p nayaya_db < seed.sql
--
--  Run schema/schema.sql first; this file assumes the tables exist.
--
--  ---------------------------------------------------------------------------
--  EVERY FILE HERE IS IDEMPOTENT. Re-running the suite is safe: rows are matched
--  on their natural keys (role name, resource+action, email) and conflicts are
--  either refreshed with new descriptive text or turned into no-ops. Nothing is
--  duplicated and no credential is reset.
--
--  ORDER IS LOAD-BEARING. Grants join roles to permissions by name, so both must
--  exist first; the admin account needs the roles to attach to.
--
--  NOT SAMPLE DATA. This is reference data that ships with the product and runs
--  in production. Fake users and demo content belong in tests/fixtures/, not here.
--
--  REQUIRES: MySQL 8.0.19+ (row alias form of ON DUPLICATE KEY UPDATE)
-- =============================================================================

USE nayaya_db;

SET NAMES utf8mb4;

-- One transaction: a half-seeded authorization table is worse than an unseeded
-- one, because the failure is silent -- endpoints just start returning 403.
START TRANSACTION;


-- -----------------------------------------------------------------------------
--  1. Roles -- no dependencies
-- -----------------------------------------------------------------------------
SOURCE seed_roles.sql;


-- -----------------------------------------------------------------------------
--  2. Permission catalogue -- no dependencies
-- -----------------------------------------------------------------------------
SOURCE seed_permissions.sql;


-- -----------------------------------------------------------------------------
--  3. Grants -- requires both of the above
-- -----------------------------------------------------------------------------
SOURCE seed_role_permissions.sql;


-- -----------------------------------------------------------------------------
--  4. Bootstrap administrator -- requires roles
--     Reads the committed development password unless you override
--     @admin_email / @admin_password_hash. See that file's header.
-- -----------------------------------------------------------------------------
SOURCE seed_admin_user.sql;


COMMIT;


-- -----------------------------------------------------------------------------
--  Summary
-- -----------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM roles)                                    AS roles,
    (SELECT COUNT(*) FROM permissions)                              AS permissions,
    (SELECT COUNT(*) FROM role_permissions
      JOIN roles r ON r.id = role_permissions.role_id
     WHERE r.name = 'admin')                                        AS admin_grants,
    (SELECT COUNT(*) FROM role_permissions
      JOIN roles r ON r.id = role_permissions.role_id
     WHERE r.name = 'user')                                         AS user_grants,
    (SELECT COUNT(*) FROM users)                                    AS users;

SELECT 'Seed data applied successfully.' AS status;
