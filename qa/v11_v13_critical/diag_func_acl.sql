\pset pager off
\echo '--- 1. get_business_period_summary 当前 ACL ---'
SELECT p.proname, COALESCE(p.proacl::text, '(default=PUBLIC EXECUTE)') acl
FROM pg_proc p WHERE p.proname='get_business_period_summary';
\echo '--- 2. agent_readonly 对该函数是否有 EXECUTE ---'
SELECT EXISTS(SELECT 1 FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) x
              WHERE pg_get_userbyid(x.grantee)='agent_readonly' AND x.privilege_type='EXECUTE') AS ar_exec,
       EXISTS(SELECT 1 FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) x
              WHERE x.grantee=0 AND x.privilege_type='EXECUTE') AS public_exec
FROM pg_proc p WHERE p.proname='get_business_period_summary';
\echo '--- 3. 今天哪些函数 proacl 含 agent_readonly ---'
SELECT count(*) FROM pg_proc p WHERE p.proacl IS NOT NULL AND p.proacl::text LIKE '%agent_readonly%';
\echo '--- 4. agent_readonly 角色属性 ---'
SELECT rolname, rolsuper, rolcanlogin, rolconfig FROM pg_roles WHERE rolname='agent_readonly';
\echo '--- 5. 隔离库是否存在（确认已删） ---'
SELECT datname FROM pg_database WHERE datname LIKE '%restore%';
\echo '--- 6. 全库 SECURITY DEFINER 函数 PUBLIC EXECUTE 现状 ---'
SELECT count(*) FILTER (WHERE p.proacl IS NULL OR 'PUBLIC' IN (SELECT x.privilege_type FROM aclexplode(p.proacl) x WHERE x.grantee=0)) AS pub_exec_open,
       count(*) AS total
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='mart' AND p.prosecdef;
