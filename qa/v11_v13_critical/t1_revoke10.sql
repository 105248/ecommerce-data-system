-- P2 清零①：REVOKE 10 个不必要 PUBLIC EXECUTE（按真实签名）
-- 原则：PUBLIC 不调用全部收权；保留 agent_readonly 精确权限；不改业务逻辑
-- mart 查询接口（get_business_report 保留 agent_readonly EXECUTE，其 ACL 已含）
REVOKE ALL ON FUNCTION mart.get_business_report(p_start_date date, p_end_date date) FROM PUBLIC;
-- mart 内部诊断函数（由 SECURITY DEFINER get_diagnostic_snapshot 内部调用，无需 PUBLIC）
REVOKE ALL ON FUNCTION mart._diag_master_product(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_entity_id text, p_entity_name text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart._diag_product_line(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_entity_name text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.check_mapping_period_conflict(p_platform_code text, p_shop_id bigint, p_platform_product_id text, p_valid_from date, p_valid_to date, p_exclude_mapping_id bigint) FROM PUBLIC;
-- meta 触发器/维护函数（触发器机制调用无需 EXECUTE；维护由 postgres/专用角色执行）
REVOKE ALL ON FUNCTION meta.audit_mapping() FROM PUBLIC;
REVOKE ALL ON FUNCTION meta.audit_masterdata() FROM PUBLIC;
REVOKE ALL ON FUNCTION meta.gen_master_product_code() FROM PUBLIC;
REVOKE ALL ON FUNCTION meta.gen_master_sku_code() FROM PUBLIC;
REVOKE ALL ON FUNCTION meta.check_chinese_coverage() FROM PUBLIC;
REVOKE ALL ON FUNCTION meta.refresh_chinese_views() FROM PUBLIC;
