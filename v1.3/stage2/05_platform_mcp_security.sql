-- ============================================================================
-- V1.3 阶段2 安全层：平台 4 函数权限（SECURITY DEFINER + PUBLIC 无 + agent_readonly）
-- ============================================================================
REVOKE ALL ON FUNCTION mart.get_platform_business_period_summary(text,date,date,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.compare_platform_business(text,date,date,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_shop_contribution(text,date,date,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.decompose_platform_change_by_shop(text,date,date,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_platform_diagnostic_snapshot(text,date,date,text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION mart.get_platform_business_period_summary(text,date,date,text) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.compare_platform_business(text,date,date,text,text) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_shop_contribution(text,date,date,text,text) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.decompose_platform_change_by_shop(text,date,date,text,text) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_platform_diagnostic_snapshot(text,date,date,text) TO agent_readonly;
