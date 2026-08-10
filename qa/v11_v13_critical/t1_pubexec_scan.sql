-- 第一步：10 个 PUBLIC EXECUTE 候选函数真实签名与 ACL 核对
\pset pager off
\echo '=== 1. 候选函数真实签名 + prosecdef + ACL ==='
SELECT n.nspname AS schema, p.proname, pg_get_function_identity_arguments(p.oid) AS args,
       p.prosecdef, COALESCE(p.proacl::text, '(NULL=默认 PUBLIC EXECUTE)') AS acl
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE (n.nspname = 'mart' AND p.proname IN
       ('get_business_report','_diag_master_product','_diag_product_line','check_mapping_period_conflict'))
   OR (n.nspname = 'meta' AND p.proname IN
       ('audit_mapping','audit_masterdata','gen_master_product_code','gen_master_sku_code',
        'check_chinese_coverage','refresh_chinese_views'))
ORDER BY 1,2;

\echo '=== 2. 全库仍有 PUBLIC EXECUTE 的函数（SECURITY DEFINER + 普通） ==='
SELECT n.nspname AS schema, p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef,
       COALESCE(p.proacl::text, '(NULL)') acl
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('core','mart','meta','audit') AND p.proname NOT LIKE 'pg_%'
  AND EXISTS (SELECT 1 FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) x
              WHERE x.grantee = 0 AND x.privilege_type = 'EXECUTE')
ORDER BY 1,2;
