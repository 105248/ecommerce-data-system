-- ============================================================================
-- V1.1 阶段5 安全层：agent_readonly 只查（不 generate）
-- ============================================================================
REVOKE ALL ON FUNCTION mart.generate_daily_action_items(text,date,date) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_daily_risk_priorities(text,date,date,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_daily_opportunity_priorities(text,date,date,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_daily_action_list(text,date,date,text,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_daily_business_brief(text,date,date) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION mart.get_daily_risk_priorities(text,date,date,integer) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_daily_opportunity_priorities(text,date,date,integer) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_daily_action_list(text,date,date,text,integer) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_daily_business_brief(text,date,date) TO agent_readonly;
GRANT SELECT ON mart.daily_action_item, mart.priority_entity_weight TO agent_readonly;
