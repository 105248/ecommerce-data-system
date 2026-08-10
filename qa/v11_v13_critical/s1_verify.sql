-- 阶段1 核实：真实表结构（确定业务唯一键）、比例列量级、sheet映射
\pset pager off
\echo '=== A. 各表列清单（找完整维度键） ==='
SELECT table_name, string_agg(column_name, ',' ORDER BY ordinal_position) cols
FROM information_schema.columns WHERE table_schema='core'
GROUP BY table_name ORDER BY table_name;

\echo '=== B. 疑似比例列 最大值/最小值（判断是否二次除100） ==='
SELECT 'ad_attributed_refund_rate_pay_time' col, min(ad_attributed_refund_rate_pay_time) mn, max(ad_attributed_refund_rate_pay_time) mx,
       count(*) FILTER (WHERE ad_attributed_refund_rate_pay_time < 0.001) tiny, count(*) n
FROM core.douyin_account_daily;
SELECT 'exposure_to_transaction_rate_events' col, min(exposure_to_transaction_rate_events) mn, max(exposure_to_transaction_rate_events) mx,
       count(*) FILTER (WHERE exposure_to_transaction_rate_events < 0.001) tiny, count(*) n
FROM core.douyin_account_daily;
SELECT 'refund_rate_pay_time' col, min(refund_rate_pay_time) mn, max(refund_rate_pay_time) mx,
       count(*) FILTER (WHERE refund_rate_pay_time < 0.001) tiny, count(*) n
FROM core.douyin_account_daily;

\echo '=== C. source_sheet_mapping（sheet→目标表） ==='
SELECT source_sheet_name, target_schema, target_table, count(*) n FROM meta.field_mapping
GROUP BY 1,2,3 ORDER BY 3,1;
