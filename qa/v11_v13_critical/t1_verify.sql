-- 第一步验证：PUBLIC EXECUTE = 0 + 权限边界
\pset pager off
\echo '=== 1. 全库业务函数 PUBLIC EXECUTE 剩余 ==='
SELECT n.nspname AS schema, p.proname, COALESCE(p.proacl::text, '(NULL)') acl
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('core','mart','meta','audit') AND p.proname NOT LIKE 'pg_%'
  AND EXISTS (SELECT 1 FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) x
              WHERE x.grantee = 0 AND x.privilege_type = 'EXECUTE');
\echo '=== 2. get_business_report ACL（应保留 agent_readonly，PUBLIC 移除） ==='
SELECT COALESCE(p.proacl::text, '(NULL)') acl FROM pg_proc p WHERE p.proname='get_business_report';
