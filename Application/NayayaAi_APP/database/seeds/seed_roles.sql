-- =============================================================================
--  seed: roles
-- =============================================================================
--  The two roles the application ships with. Both are is_system = TRUE, so the
--  admin API must refuse to delete or rename them -- the auth layer resolves
--  'admin' by name, and renaming it would silently unprotect every admin route.
--
--  IDEMPOTENT. ON DUPLICATE KEY UPDATE refreshes the human-facing text but never
--  touches `name`, so re-running after a copy edit is safe and re-running after
--  someone renamed a role by hand does not fight them on the identifier.
--
--  Add new roles here, not by hand in production. A role that exists only in one
--  environment is how "works on staging" starts.
-- =============================================================================

INSERT INTO roles (name, display_name, description, is_system) VALUES
    ('admin', 'Administrator',
     'Full access: user management, role assignment, audit trail, all files.',
     TRUE),

    ('user',  'Standard User',
     'Default role granted at registration. Self-scoped access only.',
     TRUE)
AS new
ON DUPLICATE KEY UPDATE
    display_name = new.display_name,
    description  = new.description,
    is_system    = new.is_system;
