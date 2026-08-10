-- s13_restore_validate.sql  隔离恢复验证
\pset format unaligned
\pset tuples_only on
\pset fieldsep '|'

-- 1. Schema 数量
SELECT 'SCHEMA_COUNT', count(*) FROM pg_namespace
WHERE nspname NOT IN ('pg_catalog','information_schema')
  AND nspname NOT LIKE 'pg_toast%' AND nspname NOT LIKE 'pg_temp%';

-- 2. 核心表数量（core）
SELECT 'CORE_TABLES', count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='core' AND c.relkind='r';

-- 3. 核心事实记录数（9 表总和）
SELECT 'CORE_ROWS', sum(reltuples::bigint) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='core' AND c.relkind='r';

-- 4. meta 主数据
SELECT 'MASTER_PRODUCT', count(*) FROM meta.master_product;
SELECT 'PLATFORM_PRODUCT_MAPPING', count(*) FROM meta.platform_product_mapping;
SELECT 'SHOPS', count(*) FROM meta.shop;
SELECT 'PRODUCT_LINES', count(*) FROM meta.product_line;
SELECT 'FIELD_MAPPING', count(*) FROM meta.field_mapping;
SELECT 'METRIC_RULES', count(*) FROM meta.metric_formula_rule;

-- 5. mart 核心函数（SECURITY DEFINER + 关键函数）
SELECT 'MART_FUNCS', count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='mart' AND p.prokind='f';

-- 6. MCP 白名单函数可执行性抽样（3 个代表性函数）
SELECT 'FN_BUSINESS_REPORT', count(*) FROM mart.get_business_report('2026-06-01'::date,'2026-06-30'::date);
SELECT 'FN_RANK_PRODUCTS', count(*) FROM mart.rank_products('弹动官方旗舰店','2026-06-01'::date,'2026-06-30'::date,'user_pay_amount','current_value','desc',5,NULL,NULL);
SELECT 'FN_DIAGNOSTIC', count(*) FROM mart.get_diagnostic_snapshot('弹动官方旗舰店','2026-06-01'::date,'2026-06-30'::date,'shop',NULL,NULL,NULL,NULL);

-- 7. 两店数据
SELECT 'SHOP1_ROWS', count(*) FROM core.douyin_deal_daily WHERE shop_id=1;
SELECT 'SHOP2_ROWS', count(*) FROM core.douyin_deal_daily WHERE shop_id=2;

-- 8. 抖音整体（两店合计，用户支付金额）
SELECT 'PLATFORM_TOTAL', sum(user_pay_amount) FROM core.douyin_deal_daily WHERE ad_period='不限';

-- 9. Master Product 汇总函数
SELECT 'FN_MASTER_PRODUCT', count(*) FROM mart.get_master_product_members(2);

-- 10. Product Line
SELECT 'PRODUCT_LINE_MEMBERS', count(*) FROM mart.get_product_line_members('鱼子酱品线');
