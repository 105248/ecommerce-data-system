-- V1.4 数据库规则核对
SELECT '公式规则总数' AS chk, count(*)::text AS val FROM meta.metric_formula_rule
UNION ALL SELECT '已确认', count(*)::text FROM meta.metric_formula_rule WHERE rule_status = '已确认'
UNION ALL SELECT '已明确', count(*)::text FROM meta.metric_formula_rule WHERE rule_status = '已明确'
UNION ALL SELECT '待平台口径确认', count(*)::text FROM meta.metric_formula_rule WHERE rule_status = '待平台口径确认'
UNION ALL SELECT '缺基础字段', count(*)::text FROM meta.metric_formula_rule WHERE rule_status = '缺基础字段'
UNION ALL SELECT '待首轮对账确认', count(*)::text FROM meta.metric_formula_rule WHERE rule_status = '待首轮对账确认'
UNION ALL SELECT 'auto_use_allowed=true', count(*)::text FROM meta.metric_formula_rule WHERE auto_use_allowed = TRUE
UNION ALL SELECT '剔除退款分母=settlement_amount', count(*)::text FROM meta.metric_formula_rule
    WHERE target_column_name LIKE '%net_refund%' AND denominator_expression = 'settlement_amount'
UNION ALL SELECT '剔除退款分母残留net_transaction', count(*)::text FROM meta.metric_formula_rule
    WHERE target_column_name LIKE '%net_refund%' AND denominator_expression = 'net_transaction_amount';
