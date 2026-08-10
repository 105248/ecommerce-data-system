-- ============================================================================
-- V1.1 阶段1｜经营指标诊断基础层
-- 04_diagnostic_security.sql（安全层）
-- ============================================================================
-- 原则（与既有 V1.0/6.1 一致）：
--   SECURITY DEFINER + 固定 search_path（主函数已定义时设置）
--   PUBLIC 无 EXECUTE
--   agent_readonly 只执行批准 Function（3 个）
--   内部 _diag_* 不授权（agent_readonly 不可直接调用，仅由主函数经 DEFINER 调用）
--   core 无直接 SELECT（agent_readonly 既有边界，本文件再确认）
-- ============================================================================

-- 主函数与目录函数已定义；这里做权限收紧
REVOKE ALL ON FUNCTION mart.get_diagnostic_snapshot(text,date,date,text,text,text,text,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_diagnostic_supported_metrics() FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_diagnostic_entity_metrics(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.resolve_diagnostic_period(text,date,integer) FROM PUBLIC;

-- agent_readonly 仅批准以下 3 个入口
GRANT EXECUTE ON FUNCTION mart.get_diagnostic_snapshot(text,date,date,text,text,text,text,integer) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_diagnostic_supported_metrics() TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_diagnostic_entity_metrics(text) TO agent_readonly;

-- 内部实现函数不对外授权（agent_readonly 不能直接调用）
REVOKE ALL ON FUNCTION mart._diag_shop(text,date,date,date,date) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart._diag_scope(text,date,date,date,date,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart._diag_product(text,date,date,date,date,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart._diag_carrier(text,date,date,date,date,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart._diag_account(text,date,date,date,date,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart._diag_category(text,date,date,date,date,integer) FROM PUBLIC;

-- 确认主函数安全属性（SECURITY DEFINER + search_path 已在 02 文件定义）
COMMENT ON FUNCTION mart.get_diagnostic_snapshot(text,date,date,text,text,text,text,integer) IS
'V1.1 统一诊断快照（SECURITY DEFINER，固定 search_path；agent_readonly 可执行；内部 _diag_* 不对外）。';
