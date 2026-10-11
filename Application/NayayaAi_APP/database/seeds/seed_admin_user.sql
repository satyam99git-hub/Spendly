-- =============================================================================
--  seed: bootstrap administrator
-- =============================================================================
--                          >>> READ THIS BEFORE DEPLOYING <<<
--
--  The default credentials below are DEVELOPMENT ONLY. They are committed to the
--  repository, which means they are public knowledge for anyone with read access.
--
--      email     admin@nayaya.local
--      password  Admin@123456
--
--  In any environment reachable from a network other than your laptop, do ONE of:
--
--    (a) override the variables below before running --
--          mysql -u root -p nayaya_db \
--            --init-command="SET @admin_email='you@example.com', \
--                                @admin_password_hash='<your bcrypt hash>';" \
--            < seed_admin_user.sql
--
--    (b) skip this file entirely and use the interactive script, which prompts
--        for a password and never writes it to disk --
--          python backend/scripts/create_superuser.py
--
--  Generate a hash with:
--      python -c "import bcrypt;print(bcrypt.hashpw(b'YOUR_PASSWORD',bcrypt.gensalt(12)).decode())"
--
--  ---------------------------------------------------------------------------
--  IDEMPOTENT, AND DELIBERATELY NON-DESTRUCTIVE ON RE-RUN.
--
--  The ON DUPLICATE KEY clause touches ONLY the primary key (a no-op that hands
--  back the existing id). It does NOT refresh password_hash. That is the whole
--  point: re-running the seed suite after the operator has rotated the admin
--  password must not silently reset it to the value printed above. If you ever
--  add columns to that UPDATE list, keep password_hash out of it.
-- =============================================================================

SET @admin_email         = IFNULL(@admin_email,         'admin@nayaya.local');
SET @admin_name          = IFNULL(@admin_name,          'System Administrator');
SET @admin_password_hash = IFNULL(@admin_password_hash,
                                  '$2b$12$p2RWq3/RDYHzkHYIhoHgsOeZsXnAZ5TVB9.r.MuKSq/weG5K2VoVm');


-- -----------------------------------------------------------------------------
--  Create (or locate) the account.
--  LAST_INSERT_ID(id) is the standard idiom for "give me the row id whether I
--  just inserted it or it was already there".
-- -----------------------------------------------------------------------------
INSERT INTO users (
    public_id,
    email,
    password_hash,
    full_name,
    auth_provider,
    is_email_verified,
    email_verified_at,
    is_active,
    password_changed_at
) VALUES (
    UUID(),
    @admin_email,
    @admin_password_hash,
    @admin_name,
    'local',
    TRUE,                 -- pre-verified, or the bootstrap admin cannot log in
    UTC_TIMESTAMP(),
    TRUE,
    UTC_TIMESTAMP()
)
ON DUPLICATE KEY UPDATE
    id = LAST_INSERT_ID(id);   -- no-op; never overwrite an existing password

SET @admin_id = LAST_INSERT_ID();


-- -----------------------------------------------------------------------------
--  Grant both roles.
--
--  'user' as well as 'admin' because promotion is additive in this model (see
--  schema/user_roles.sql) -- an administrator is a normal account that also holds
--  the admin role, not a separate species. Keeping 'user' on the row means the
--  admin still resolves correctly anywhere the code asks "is this a user".
-- -----------------------------------------------------------------------------
INSERT INTO user_roles (user_id, role_id, assigned_by)
SELECT @admin_id, r.id, NULL          -- NULL assigned_by = granted by the system
FROM roles r
WHERE r.name IN ('admin', 'user')
ON DUPLICATE KEY UPDATE user_id = user_roles.user_id;   -- no-op on conflict


-- -----------------------------------------------------------------------------
--  Fail loudly if the committed development password survived into this database.
-- -----------------------------------------------------------------------------
SELECT
    u.email,
    u.public_id,
    GROUP_CONCAT(r.name ORDER BY r.name) AS roles,
    CASE
        WHEN u.password_hash =
             '$2b$12$p2RWq3/RDYHzkHYIhoHgsOeZsXnAZ5TVB9.r.MuKSq/weG5K2VoVm'
        THEN '*** DEFAULT DEV PASSWORD IN USE -- ROTATE BEFORE EXPOSING THIS DB ***'
        ELSE 'custom password set'
    END AS password_status
FROM users u
JOIN user_roles ur ON ur.user_id = u.id
JOIN roles r       ON r.id = ur.role_id
WHERE u.id = @admin_id
GROUP BY u.id, u.email, u.public_id, u.password_hash;
