-- s07_security.sql  权限最终收口检查
\pset format unaligned
\pset tuples_only on
\pset fieldsep '|'

-- 1. PUBLIC 对 schema 的权限
SELECT 'SCHEMA_PUBLIC', n.nspname, COALESCE(p.privilege_type,'')
FROM pg_namespace n
LEFT JOIN LATERAL (
  SELECT DISTINCT privilege_type FROM aclexplode(COALESCE(n.nspacl, acldefault('n', n.nspowner)))
  WHERE grantee = 0
) p ON true
WHERE n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
ORDER BY 2;

-- 2. PUBLIC 对表/视图/序列的权限
SELECT 'OBJ_PUBLIC', n.nspname, c.relname, p.privilege_type
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN LATERAL (
  SELECT DISTINCT privilege_type FROM aclexplode(COALESCE(c.relacl, acldefault('r', c.relowner)))
  WHERE grantee = 0
) p
WHERE n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
  AND c.relkind IN ('r','v','m','S')
ORDER BY 1,2,3;

-- 3. PUBLIC 对函数的 EXECUTE
SELECT 'FUNC_PUBLIC', n.nspname, p.proname, p2.privilege_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
CROSS JOIN LATERAL (
  SELECT DISTINCT privilege_type FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner)))
  WHERE grantee = 0
) p2
WHERE n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
  AND p.prokind IN ('f','p')
ORDER BY 1,2,3;

-- 4. SECURITY DEFINER 函数清单
SELECT 'SECURITY_DEFINER', n.nspname, p.proname,
       pg_get_function_identity_arguments(p.oid),
       pg_get_userbyid(p.proowner),
       COALESCE((SELECT setting FROM pg_settings WHERE name='search_path' AND pg_settings IS NOT NULL), '')
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.prosecdef
  AND n.nspname NOT IN ('pg_catalog','information_schema')
ORDER BY 1,2,3;

-- 5. agent_readonly 直接可访问的表（core 是否可读）
SELECT 'AGENT_TABLES', n.nspname, c.relname
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE EXISTS (
  SELECT 1 FROM aclexplode(COALESCE(c.relacl, acldefault('r', c.relowner)))
  WHERE grantee = (SELECT oid FROM pg_roles WHERE rolname='agent_readonly')
    AND privilege_type = 'SELECT'
)
  AND n.nspname NOT IN ('pg_catalog','information_schema')
ORDER BY 1,2,3;

-- 6. agent_readonly 对函数 EXECUTE
SELECT 'AGENT_FUNCS', n.nspname, p.proname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE EXISTS (
  SELECT 1 FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner)))
  WHERE grantee = (SELECT oid FROM pg_roles WHERE rolname='agent_readonly')
    AND privilege_type = 'EXECUTE'
)
  AND n.nspname NOT IN ('pg_catalog','information_schema')
  AND p.prokind IN ('f','p')
ORDER BY 1,2,3;

-- 7. 角色成员关系
SELECT 'ROLE_MEMBERSHIP', r.rolname, m.rolname
FROM pg_auth_members am
JOIN pg_roles r ON r.oid = am.roleid
JOIN pg_roles m ON m.oid = am.member
ORDER BY 1,2;

-- 8. search_path 设置（DB 级）
SELECT 'SEARCH_PATH_DB', setting FROM pg_db_role_setting s
JOIN pg_database d ON d.oid = s.setdatabase
CROSS JOIN LATERAL unnest(s.setconfig) cfg(setting)
WHERE d.datname = current_database() AND cfg.setting LIKE 'search_path=%';
