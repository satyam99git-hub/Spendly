-- =============================================================================
--  seed: role_permissions   (which capabilities each role grants)
-- =============================================================================
--  Written as INSERT ... SELECT against roles and permissions by NAME rather than
--  by hard-coded id. Auto-increment values differ between machines; a seed keyed
--  on literal ids works on the box it was written on and quietly mis-grants
--  everywhere else.
--
--  The admin grant is a CROSS JOIN -- "every permission that exists". That is
--  self-maintaining: add a permission to seed_permissions.sql, re-run, and admin
--  picks it up. Nothing to remember, nothing to drift.
--
--  The user grant is an explicit allow-list. It has to be, because the whole
--  point is that it is a strict subset. Note what is absent: no user:*, no
--  role:*, no audit:*, no *_all / *_any. A standard account can act on its own
--  rows and nothing else.
--
--  RE-RUNNING NARROWS NOTHING. These statements add grants; they never remove
--  one. If you delete a line from the user allow-list below, re-running will not
--  revoke it -- see the optional revoke block at the foot of this file.
-- =============================================================================


-- -----------------------------------------------------------------------------
--  admin -> every permission
-- -----------------------------------------------------------------------------
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'admin'
ON DUPLICATE KEY UPDATE role_id = role_permissions.role_id;   -- no-op on conflict


-- -----------------------------------------------------------------------------
--  user -> self-scoped subset
-- -----------------------------------------------------------------------------
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p
  ON p.name IN (
      -- own profile
      'profile:read',
      'profile:update',
      'profile:delete',
      -- own files
      'file:upload',
      'file:read',
      'file:delete',
      'file:list',
      -- own notification feed
      'notification:read',
      'notification:list',
      'notification:update',
      'notification:delete',
      -- own active sessions
      'session:read',
      'session:revoke'
  )
WHERE r.name = 'user'
ON DUPLICATE KEY UPDATE role_id = role_permissions.role_id;   -- no-op on conflict


-- -----------------------------------------------------------------------------
--  OPTIONAL: make the user role exactly match the list above.
--
--  Commented out by default because it is destructive -- it revokes any grant an
--  operator added deliberately through the admin UI. Uncomment only when you want
--  this file to be the sole authority on what a standard user may do.
-- -----------------------------------------------------------------------------
-- DELETE rp FROM role_permissions rp
-- JOIN roles r       ON r.id = rp.role_id
-- JOIN permissions p ON p.id = rp.permission_id
-- WHERE r.name = 'user'
--   AND p.name NOT IN (
--       'profile:read','profile:update','profile:delete',
--       'file:upload','file:read','file:delete','file:list',
--       'notification:read','notification:list','notification:update','notification:delete',
--       'session:read','session:revoke'
--   );
