-- 阶段6.1 最小安全修复:
-- 1) 全部 SECURITY DEFINER 函数固定安全 search_path (pg_catalog 最前 + 真实依赖 schema)
-- 2) 撤销 PUBLIC 对 get_data_coverage 的 EXECUTE
DO $$
DECLARE f oid;
BEGIN
  FOR f IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
           WHERE n.nspname='mart' AND p.prosecdef
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = pg_catalog, mart, core, meta, audit', f::regprocedure);
  END LOOP;
  RAISE NOTICE '已为全部 SECURITY DEFINER 函数设置固定 search_path';
END $$;

REVOKE EXECUTE ON FUNCTION mart.get_data_coverage(text) FROM PUBLIC;

-- 验证
\echo '===== 修复后: proconfig 检查 ====='
SELECT p.oid::regprocedure AS function_signature,
       COALESCE(p.proconfig::text, '(NULL)') AS proconfig
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='mart' AND p.prosecdef
ORDER BY p.proname;

\echo ''
\echo '===== 修复后: PUBLIC EXECUTE 检查 ====='
SELECT DISTINCT p.oid::regprocedure AS function_signature,
       has_function_privilege('public', p.oid, 'EXECUTE') AS public_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='mart'
ORDER BY 1;
