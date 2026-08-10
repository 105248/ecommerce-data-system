-- ============================================================================
-- 04_mart_V1.0_阶段4_MCP_Readonly_Security.sql
-- 目标：建立 MCP 专用只读数据库角色与最小权限
-- 注意：
-- 1. 不在本文件写真实密码。
-- 2. WorkBuddy 需在本机生成随机强密码后 ALTER ROLE。
-- 3. 只允许 mart/meta/audit 必要读取与已批准 Function EXECUTE。
-- 4. 不授予 core 表直接 SELECT 给 MCP V1.0。
-- ============================================================================

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'agent_readonly') THEN
        CREATE ROLE agent_readonly LOGIN;
    END IF;
END
$$;

-- 安全基线
ALTER ROLE agent_readonly NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS;

ALTER ROLE agent_readonly PASSWORD '__PG_ADMIN_PASSWORD_FROM_ENV__';

-- 连接数据库（数据库名如不是 ecommerce_db，WorkBuddy 做最小适配）
GRANT CONNECT ON DATABASE ecommerce_db TO agent_readonly;

-- 默认不给 public 额外对象创建权限
REVOKE CREATE ON SCHEMA public FROM agent_readonly;

-- Schema访问
GRANT USAGE ON SCHEMA mart TO agent_readonly;
GRANT USAGE ON SCHEMA meta TO agent_readonly;
GRANT USAGE ON SCHEMA audit TO agent_readonly;

-- 明确取消业务写权限
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON ALL TABLES IN SCHEMA mart, meta, audit
FROM agent_readonly;

REVOKE CREATE ON SCHEMA mart, meta, audit FROM agent_readonly;

-- 基础只读目录
GRANT SELECT ON TABLE meta.shop TO agent_readonly;

-- Stage1/2/3 治理与指标目录（存在时由WorkBuddy按实际对象授权）
DO $$
BEGIN
    IF to_regclass('mart.analysis_metric_whitelist') IS NOT NULL THEN
        EXECUTE 'GRANT SELECT ON TABLE mart.analysis_metric_whitelist TO agent_readonly';
    END IF;

    IF to_regclass('mart.metric_rule_v14') IS NOT NULL THEN
        EXECUTE 'GRANT SELECT ON TABLE mart.metric_rule_v14 TO agent_readonly';
    END IF;

    IF to_regclass('mart.stage3_expected_scope_map') IS NOT NULL THEN
        EXECUTE 'GRANT SELECT ON TABLE mart.stage3_expected_scope_map TO agent_readonly';
    END IF;

    IF to_regclass('mart.mart_dimension_rule') IS NOT NULL THEN
        EXECUTE 'GRANT SELECT ON TABLE mart.mart_dimension_rule TO agent_readonly';
    END IF;
END
$$;

-- 默认撤销所有 mart Functions 的执行权限，再对白名单重新授权。
-- 注意：PostgreSQL函数默认可能PUBLIC可执行，因此必须收紧。
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA mart FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA mart FROM agent_readonly;

-- 公开 Function 白名单：
-- 用DO块按函数名授权全部重载；执行前WorkBuddy必须检查没有同名危险重载。
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT p.oid::regprocedure AS sig
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'mart'
          AND p.proname IN (
              'get_business_period_summary',
              'get_carrier_period_summary',
              'get_account_period_summary',
              'get_content_period_summary',
              'get_terminal_period_summary',
              'get_category_period_summary',
              'get_product_period_summary',
              'get_price_band_period_summary',
              'get_audience_period_summary',
              'compare_business_period',
              'rank_sale_scopes',
              'rank_carriers',
              'rank_products',
              'rank_accounts',
              'rank_categories',
              'rank_contents',
              'rank_terminals',
              'rank_price_bands',
              'rank_audiences',
              'get_business_contribution',
              'get_product_contribution',
              'get_account_contribution',
              'get_category_contribution'
          )
    LOOP
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO agent_readonly', r.sig);
    END LOOP;
END
$$;

-- 现有对象未来默认权限：不自动给 agent_readonly 写权限。
ALTER DEFAULT PRIVILEGES IN SCHEMA mart
REVOKE ALL ON TABLES FROM agent_readonly;

ALTER DEFAULT PRIVILEGES IN SCHEMA mart
REVOKE ALL ON FUNCTIONS FROM agent_readonly;

-- 只读事务偏好 + 超时
ALTER ROLE agent_readonly SET default_transaction_read_only = on;
ALTER ROLE agent_readonly SET statement_timeout = '10s';
ALTER ROLE agent_readonly SET idle_in_transaction_session_timeout = '30s';
ALTER ROLE agent_readonly SET lock_timeout = '3s';

COMMIT;

-- ============================================================================
-- 验收查询（WorkBuddy以管理员执行）
-- ============================================================================

-- 1. 角色属性
SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolreplication, rolbypassrls
FROM pg_roles
WHERE rolname='agent_readonly';

-- 2. Schema权限
SELECT
    has_schema_privilege('agent_readonly','mart','USAGE') AS mart_usage,
    has_schema_privilege('agent_readonly','mart','CREATE') AS mart_create,
    has_schema_privilege('agent_readonly','meta','USAGE') AS meta_usage,
    has_schema_privilege('agent_readonly','audit','USAGE') AS audit_usage;

-- 3. 核心表写权限应全部false
SELECT
    has_table_privilege('agent_readonly','meta.shop','SELECT') AS shop_select,
    has_table_privilege('agent_readonly','meta.shop','INSERT') AS shop_insert,
    has_table_privilege('agent_readonly','meta.shop','UPDATE') AS shop_update,
    has_table_privilege('agent_readonly','meta.shop','DELETE') AS shop_delete;

-- 4. mart公开Function授权清单
SELECT
    p.oid::regprocedure::text AS function_signature,
    has_function_privilege('agent_readonly', p.oid, 'EXECUTE') AS can_execute
FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='mart'
ORDER BY p.proname, p.oid::regprocedure::text;

-- 5. core数据保护基线（管理员执行）
SELECT
    (SELECT COUNT(*) FROM core.douyin_deal_daily) +
    (SELECT COUNT(*) FROM core.douyin_carrier_daily) +
    (SELECT COUNT(*) FROM core.douyin_account_daily) +
    (SELECT COUNT(*) FROM core.douyin_content_daily) +
    (SELECT COUNT(*) FROM core.douyin_terminal_daily) +
    (SELECT COUNT(*) FROM core.douyin_category_daily) +
    (SELECT COUNT(*) FROM core.douyin_product_daily) +
    (SELECT COUNT(*) FROM core.douyin_price_band_daily) +
    (SELECT COUNT(*) FROM core.douyin_audience_daily)
AS core_total_rows;
