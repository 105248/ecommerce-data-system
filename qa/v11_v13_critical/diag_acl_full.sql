-- 全量 ACL 诊断：62 个 SECURITY DEFINER 函数逐个授权状态
\pset pager off
\echo '=== 1. 62 个 SECURITY DEFINER 函数 ACL 现状 ==='
SELECT p.proname,
       COALESCE(p.proacl::text, '(NULL=默认)') AS acl
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE p.prosecdef AND n.nspname='mart' AND p.proname NOT LIKE 'pg_%'
ORDER BY p.proname;

\echo '=== 2. 无 agent_readonly 授权（含 NULL/仅postgres/PUBLIC） ==='
SELECT p.proname,
       COALESCE(p.proacl::text, '(NULL)') acl,
       EXISTS(SELECT 1 FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) x WHERE x.grantee=0 AND x.privilege_type='EXECUTE') AS pub_open
FROM pg_proc p WHERE p.prosecdef AND p.proname NOT LIKE 'pg_%'
  AND NOT EXISTS(SELECT 1 FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) x
                 WHERE pg_get_userbyid(x.grantee)='agent_readonly' AND x.privilege_type='EXECUTE')
ORDER BY p.proname;
