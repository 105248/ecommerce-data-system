-- s13_restore_validate2.sql  恢复验证补充（18 Scope + V1.1 + 对比基准）
\pset format unaligned
\pset tuples_only on
\pset fieldsep '|'

-- 18 Scope 解析全通
SELECT 'SCOPE_TOTAL', count(*) FROM mart.resolve_scope('全店');
SELECT 'SCOPE_18', count(*) FROM (
  VALUES ('全店'),('自营'),('合作'),('商品卡'),('短视频'),('直播'),('图文'),('其他'),
         ('自营直播'),('自营商品'),('达人直播'),('达人短视频'),('橱窗'),
         ('自营短视频'),('自营图文'),('达人商品'),('达人图文'),('全部')
) v(s);
SELECT 'SCOPE_RESOLVE_OK', count(*) FROM (VALUES ('全店'),('自营'),('合作'),('商品卡'),('短视频'),('直播'),('图文'),('其他'),
         ('自营直播'),('自营商品'),('达人直播'),('达人短视频'),('橱窗'),
         ('自营短视频'),('自营图文'),('达人商品'),('达人图文'),('全部')) v(s)
CROSS JOIN LATERAL mart.resolve_scope(s);

-- V1.1 关键查询：异常检测函数可执行 + 事件表可读
SELECT 'V11_ANOMALY_EVENTS', count(*) FROM mart.anomaly_event;
SELECT 'V11_DIAG_RESULTS', count(*) FROM mart.diagnostic_result;
SELECT 'V11_ACTION_ITEMS', count(*) FROM mart.daily_action_item;
SELECT 'V11_OPPORTUNITIES', count(*) FROM mart.opportunity_event;

-- V1.1 诊断查询（实体诊断入口可执行）
SELECT 'V11_DIAGNOSE', count(*) FROM mart.diagnose_anomaly(
  (SELECT anomaly_event_id FROM mart.anomaly_event WHERE domain_key='shop' LIMIT 1));

-- 平台整体函数
SELECT 'PLATFORM_SUMMARY', count(*) FROM mart.get_platform_business_period_summary('douyin','2026-06-01'::date,'2026-06-30'::date,'全店');

-- Master Product 汇总
SELECT 'MP_SUMMARY', count(*) FROM mart.get_master_product_period_summary(2,'2026-06-01'::date,'2026-06-30'::date,NULL);

-- 中文数据视图可用性
SELECT 'CN_VIEWS', count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='中文数据' AND c.relkind='v';
