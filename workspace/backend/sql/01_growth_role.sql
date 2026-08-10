-- F0.5-B：growth_workspace_reader 动态授权（按 04 白名单 54 接口，pg_proc 真实签名）
-- 避免手写签名错误；只读消费
-- 密码安全（P1-10）：必须通过 psql 变量 -v growth_pw=... 提供，禁止占位符创建；未提供直接 FAIL
\if :{?growth_pw}
\else
\echo 'ERROR: 必须通过 -v growth_pw=<密码> 提供 growth_workspace_reader 密码（禁止使用 [REDACTED] 占位创建角色）'
\quit 1
\endif

DO $$
DECLARE
    fn_name text;
    rec record;
    -- 白名单 46 个 FUNCTION（04 whitelist 的 FUNCTION 类型）
    fn_list text[] := ARRAY[
        'compare_advertising_period','compare_business_period','compare_platform_business',
        'decompose_master_product_by_shop_product','decompose_platform_change_by_shop',
        'get_account_contribution','get_account_period_summary','get_advertising_diagnosis',
        'get_advertising_period_summary','get_anomalies','get_anomaly_summary',
        'get_audience_period_summary','get_business_period_summary','get_business_report',
        'get_carrier_period_summary','get_category_contribution','get_category_period_summary',
        'get_content_period_summary','get_daily_action_list','get_daily_business_brief',
        'get_daily_opportunity_priorities','get_daily_risk_priorities','get_data_coverage',
        'get_diagnostic_result','get_diagnostic_snapshot','get_diagnostic_supported_metrics',
        'get_entity_anomalies','get_entity_opportunity','get_funnel_diagnosis',
        'get_growth_opportunities','get_master_product_members','get_opportunity_summary',
        'get_platform_business_period_summary','get_platform_diagnostic_snapshot',
        'get_price_band_period_summary','get_product_contribution','get_product_period_summary',
        'get_shop_contribution','get_terminal_period_summary','rank_accounts','rank_audiences',
        'rank_carriers','rank_categories','rank_price_bands','rank_products','resolve_master_product'
    ];
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'growth_workspace_reader') THEN
        EXECUTE format('CREATE ROLE growth_workspace_reader LOGIN PASSWORD %L', :'growth_pw');
    END IF;
    EXECUTE 'GRANT CONNECT ON DATABASE ecommerce_db TO growth_workspace_reader';
    EXECUTE 'GRANT USAGE ON SCHEMA mart, meta, audit TO growth_workspace_reader';
    -- 函数 EXECUTE
    FOR rec IN
        SELECT n.nspname AS sch, p.proname AS fn, pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'mart' AND p.proname = ANY(fn_list)
    LOOP
        EXECUTE format('GRANT EXECUTE ON FUNCTION %I.%I(%s) TO growth_workspace_reader',
                       rec.sch, rec.fn, rec.args);
    END LOOP;
END $$;

-- 白名单 TABLE/VIEW SELECT（8 个）
GRANT SELECT ON
    mart.analysis_metric_whitelist, mart.product_mapping_conflicts, mart.unmapped_products,
    meta.master_product, meta.platform_product_mapping, meta.product_line, meta.shop,
    audit.import_batch
TO growth_workspace_reader;

COMMENT ON ROLE growth_workspace_reader IS 'F0.5 Backend HTTP API 只读角色：仅消费正式白名单 54 接口';
\echo 'growth_workspace_reader 动态授权完成'
