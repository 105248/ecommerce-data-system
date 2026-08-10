-- s04_roles_grants.sql  角色与授权盘点
\pset format unaligned
\pset tuples_only on
\pset fieldsep '|'

-- 角色
SELECT r.rolname,
       r.rolsuper,
       r.rolcreaterole,
       r.rolcreatedb,
       r.rolcanlogin,
       r.rolreplication,
       r.rolconnlimit::text,
       r.rolvaliduntil::text
FROM pg_roles r
WHERE r.rolname NOT LIKE 'pg_%'
ORDER BY 1;

-- Schema 权限
SELECT n.nspname, c.rolname, p.privilege_type
FROM pg_namespace n
CROSS JOIN LATERAL aclexplode(COALESCE(n.nspacl, acldefault('n', n.nspowner))) p
JOIN pg_roles c ON c.oid = p.grantee
WHERE n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
ORDER BY 1, 2, 3;

-- 表级权限（core 表）
SELECT n.nspname, c.relname, gr.rolname, p.privilege_type
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl, acldefault('r', c.relowner))) p
JOIN pg_roles gr ON gr.oid = p.grantee
WHERE n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
  AND c.relkind IN ('r','v','m','S')
  AND gr.rolname NOT IN ('postgres','pg_database_owner')
ORDER BY 1, 2, 3, 4;

-- 函数执行权限
SELECT n.nspname, p.proname, gr.rolname, p2.privilege_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) p2
JOIN pg_roles gr ON gr.oid = p2.grantee
WHERE n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
  AND gr.rolname NOT IN ('postgres')
  AND gr.rolname <> p.proowner::regrole::text
ORDER BY 1, 2, 3, 4;
