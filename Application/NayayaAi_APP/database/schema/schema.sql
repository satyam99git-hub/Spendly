-- =============================================================================
--  NayayaAi -- authoritative schema bootstrap
-- =============================================================================
--  Creates the database and every table, in foreign-key dependency order.
--
--  USAGE (must run from this directory -- SOURCE paths are relative to the CWD):
--
--      cd database/schema
--      mysql -u root -p < schema.sql
--
--  This file deliberately holds no CREATE TABLE statements of its own. Each table
--  is defined once, in its own file, and included here. One definition, one place
--  to change it.
--
--  RELATIONSHIP TO ALEMBIC
--  Alembic is the runtime source of truth once the app is deployed; migrations in
--  backend/migrations/versions/ are what actually mutate production. These files
--  exist to (a) document the intended shape, (b) bootstrap a fresh local or CI
--  database in one command, and (c) give the ER diagram something to be generated
--  from. After changing a table here, generate the matching Alembic revision --
--  the two must not drift.
--
--  CONVENTIONS APPLIED THROUGHOUT
--    - InnoDB + utf8mb4 / utf8mb4_unicode_ci (full Unicode, emoji included)
--    - BIGINT UNSIGNED surrogate PKs; CHAR(36) public_id on externally-visible rows
--    - All DATETIME values are UTC; the application is what enforces that
--    - Secrets (refresh, reset, verification tokens) stored as SHA-256 hex, never raw
--    - Soft delete via deleted_at on user-facing entities; audit_logs is append-only
--    - Explicit constraint names (fk_/uq_/idx_/chk_) so migrations can target them
--
--  REQUIRES: MySQL 8.0.19+
--    8.0.16+ for enforced CHECK constraints and the JSON type (this file)
--    8.0.19+ for the row-alias form of ON DUPLICATE KEY UPDATE (../seeds/)
--  Provision 8.0.19 or later so schema and seeds share one floor.
-- =============================================================================

CREATE DATABASE IF NOT EXISTS nayaya_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE nayaya_db;

-- Applies to this session only; the per-table files set their own engine/charset.
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 1;


-- -----------------------------------------------------------------------------
--  1. Authorization primitives -- no dependencies
-- -----------------------------------------------------------------------------
SOURCE roles.sql;
SOURCE permissions.sql;
SOURCE role_permissions.sql;


-- -----------------------------------------------------------------------------
--  2. Accounts -- depends on nothing; everything below depends on it
-- -----------------------------------------------------------------------------
SOURCE users.sql;


-- -----------------------------------------------------------------------------
--  3. Role assignment -- depends on users + roles
-- -----------------------------------------------------------------------------
SOURCE user_roles.sql;


-- -----------------------------------------------------------------------------
--  4. Authentication artefacts -- depend on users
-- -----------------------------------------------------------------------------
SOURCE refresh_tokens.sql;
SOURCE password_reset.sql;
SOURCE email_verification.sql;


-- -----------------------------------------------------------------------------
--  5. Application data -- depend on users
-- -----------------------------------------------------------------------------
SOURCE file_uploads.sql;
SOURCE notifications.sql;
SOURCE device_tokens.sql;


-- -----------------------------------------------------------------------------
--  6. Audit trail -- soft dependency on users (ON DELETE SET NULL)
-- -----------------------------------------------------------------------------
SOURCE audit_logs.sql;


-- -----------------------------------------------------------------------------
--  Done. Next steps, in order:
--    ../seeds/seed.sql        roles, permissions, initial admin
--    ../indexes/indexes.sql   optional reporting indexes (constraints are inline)
--    ../views/               read-model conveniences
--    ../procedures/          scheduled expired-token cleanup
-- -----------------------------------------------------------------------------

SELECT 'Schema created successfully.' AS status;
