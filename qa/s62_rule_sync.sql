-- 治理表维度字典同步: 平台投放时段改名 全域投放时段 -> 全域+乘方投放时段
BEGIN;
UPDATE mart.mart_dimension_rule
SET dimension_value = '全域+乘方投放时段',
    notes = COALESCE(notes, '') || ' | 2026-08-08 平台导出口径更新: 全域投放时段改名全域+乘方投放时段'
WHERE dimension_value = '全域投放时段';
COMMIT;

\echo '=== 同步后治理表投放时段相关 ==='
SELECT dimension_name, dimension_value, rule_type, rule_status
FROM mart.mart_dimension_rule
WHERE dimension_value LIKE '%全域%' OR dimension_value LIKE '%乘方%';
