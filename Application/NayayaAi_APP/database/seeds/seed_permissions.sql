-- =============================================================================
--  seed: permissions
-- =============================================================================
--  The full capability vocabulary. Endpoints depend on these strings, never on
--  role names -- that indirection is what lets you reshape roles without editing
--  route code.
--
--  SCOPE IS NOT ENCODED HERE. `profile:update` means "may update a profile at
--  all", not "may update any profile". Ownership checks stay in the service layer,
--  because the database cannot know that user 7 is asking about user 7. Treat a
--  permission as the outer gate and the ownership check as the inner one; an
--  endpoint that only does the first is a horizontal privilege escalation.
--
--  `name` must always equal resource || ':' || action. The UNIQUE key on
--  (resource, action) is what enforces no duplicates; `name` is stored because
--  it is the form the code actually compares against.
--
--  IDEMPOTENT: descriptions refresh on re-run, identifiers never change.
-- =============================================================================

INSERT INTO permissions (name, resource, action, description, is_system) VALUES
    -- ---- user administration (admin surface) --------------------------------
    ('user:create',          'user',         'create',  'Create accounts directly',                       TRUE),
    ('user:read',            'user',         'read',    'View any user record',                           TRUE),
    ('user:update',          'user',         'update',  'Modify any user record',                         TRUE),
    ('user:delete',          'user',         'delete',  'Soft-delete any account',                        TRUE),
    ('user:list',            'user',         'list',    'Browse and search all users',                    TRUE),

    -- ---- role and permission management -------------------------------------
    ('role:create',          'role',         'create',  'Define a new role',                              TRUE),
    ('role:read',            'role',         'read',    'View a role and its grants',                     TRUE),
    ('role:update',          'role',         'update',  'Modify a role or its grants',                    TRUE),
    ('role:delete',          'role',         'delete',  'Remove a non-system role',                       TRUE),
    ('role:list',            'role',         'list',    'Browse all roles',                               TRUE),
    ('role:assign',          'role',         'assign',  'Grant or revoke a role on a user',               TRUE),
    ('permission:read',      'permission',   'read',    'View a permission definition',                   TRUE),
    ('permission:list',      'permission',   'list',    'Browse the permission catalogue',                TRUE),

    -- ---- own profile (self-scoped; ownership enforced in the service) -------
    ('profile:read',         'profile',      'read',    'View own profile',                               TRUE),
    ('profile:update',       'profile',      'update',  'Edit own profile',                               TRUE),
    ('profile:delete',       'profile',      'delete',  'Delete own account',                             TRUE),

    -- ---- files ---------------------------------------------------------------
    ('file:upload',          'file',         'upload',  'Upload a file',                                  TRUE),
    ('file:read',            'file',         'read',    'Download a file',                                TRUE),
    ('file:delete',          'file',         'delete',  'Delete a file',                                  TRUE),
    ('file:list',            'file',         'list',    'Browse files',                                   TRUE),
    ('file:manage_all',      'file',         'manage_all','Act on any user''s files',                     TRUE),

    -- ---- notifications -------------------------------------------------------
    ('notification:read',    'notification', 'read',    'View a notification',                            TRUE),
    ('notification:list',    'notification', 'list',    'Browse own notification feed',                   TRUE),
    ('notification:update',  'notification', 'update',  'Mark notifications read',                        TRUE),
    ('notification:delete',  'notification', 'delete',  'Remove a notification',                          TRUE),
    ('notification:send',    'notification', 'send',    'Dispatch notifications to other users',          TRUE),

    -- ---- sessions (active devices / remote logout) --------------------------
    ('session:read',         'session',      'read',    'List own active sessions',                       TRUE),
    ('session:revoke',       'session',      'revoke',  'Revoke own session on a device',                 TRUE),
    ('session:revoke_any',   'session',      'revoke_any','Force-logout any user',                        TRUE),

    -- ---- audit ---------------------------------------------------------------
    ('audit:read',           'audit',        'read',    'View an audit entry',                            TRUE),
    ('audit:list',           'audit',        'list',    'Search the audit trail',                         TRUE)
AS new
ON DUPLICATE KEY UPDATE
    description = new.description,
    is_system   = new.is_system;
