# 03｜正式数据库接口目录（Official Database Interface Catalog）

> 数据库最终架构收口｜封版版 V1.0｜唯一正式公共接口目录
> 消费方：MCP（现行）+ Backend API（F0.5 计划）。接口状态默认 ACTIVE。

**接口总数：54**

| interface_code | schema | object_type | business_domain | parameters | security_role | used_by_mcp | http_status | status |
|---|---|---|---|---|---|---|---|---|
| audit.import_batch | audit | TABLE/VIEW | catalog |  | agent_readonly | ✅ | HTTP_NOT_REQUIRED | ACTIVE |
| mart.analysis_metric_whitelist | mart | TABLE/VIEW | business |  | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.compare_advertising_period | mart | FUNCTION | advertising | p_shop_name text, p_start_date date, p_end_date date, p_scope_key text | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.compare_business_period | mart | FUNCTION | business | p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.compare_platform_business | mart | FUNCTION | platform | p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_me | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.decompose_master_product_by_shop_product | mart | FUNCTION | product | p_master_product_id bigint, p_start_date date, p_end_date date | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.decompose_platform_change_by_shop | mart | FUNCTION | platform | p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_me | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_account_contribution | mart | FUNCTION | account | p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metri | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_account_period_summary | mart | FUNCTION | account | p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_accou | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_advertising_diagnosis | mart | FUNCTION | diagnostic | p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_sho | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_advertising_period_summary | mart | FUNCTION | advertising | p_shop_name text, p_start_date date, p_end_date date, p_scope_key text | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_anomalies | mart | FUNCTION | anomaly | p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_e | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_anomaly_summary | mart | FUNCTION | anomaly | p_platform_code text, p_start_date date, p_end_date date, p_status text | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_audience_period_summary | mart | FUNCTION | audience | p_shop_name text, p_start_date date, p_end_date date, p_audience_type text, p_ca | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_business_period_summary | mart | FUNCTION | business | p_shop_name text, p_start_date date, p_end_date date, p_scope_key text | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_business_report | mart | FUNCTION | business | p_start_date date, p_end_date date | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_carrier_period_summary | mart | FUNCTION | carrier | p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_carri | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_category_contribution | mart | FUNCTION | category | p_shop_name text, p_start_date date, p_end_date date, p_category_level integer,  | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_category_period_summary | mart | FUNCTION | category | p_shop_name text, p_start_date date, p_end_date date, p_category_level integer,  | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_content_period_summary | mart | FUNCTION | content | p_shop_name text, p_start_date date, p_end_date date, p_selling_type text, p_car | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_daily_action_list | mart | FUNCTION | priority | p_platform_code text, p_start_date date, p_end_date date, p_item_type text, p_li | agent_readonly | ✅ | HTTP_READY | ACTIVE |
| mart.get_daily_business_brief | mart | FUNCTION | priority | p_platform_code text, p_start_date date, p_end_date date | agent_readonly | ✅ | HTTP_READY | ACTIVE |
| mart.get_daily_opportunity_priorities | mart | FUNCTION | priority | p_platform_code text, p_start_date date, p_end_date date, p_limit integer | agent_readonly | ✅ | HTTP_READY | ACTIVE |
| mart.get_daily_risk_priorities | mart | FUNCTION | priority | p_platform_code text, p_start_date date, p_end_date date, p_limit integer | agent_readonly | ✅ | HTTP_READY | ACTIVE |
| mart.get_data_coverage | mart | FUNCTION | catalog | p_shop_name text | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_diagnostic_result | mart | FUNCTION | diagnostic | p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_s | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_diagnostic_snapshot | mart | FUNCTION | diagnostic | p_shop_name text, p_start_date date, p_end_date date, p_domain_key text, p_scope | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_diagnostic_supported_metrics | mart | FUNCTION | diagnostic |  | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_entity_anomalies | mart | FUNCTION | anomaly | p_platform_code text, p_domain_key text, p_entity_name text, p_start_date date,  | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_entity_opportunity | mart | FUNCTION | opportunity | p_platform_code text, p_domain_key text, p_entity_name text, p_start_date date,  | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_funnel_diagnosis | mart | FUNCTION | diagnostic | p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_sho | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_growth_opportunities | mart | FUNCTION | opportunity | p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_o | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_master_product_members | mart | FUNCTION | product | p_master_product_id bigint | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_opportunity_summary | mart | FUNCTION | opportunity | p_platform_code text, p_start_date date, p_end_date date, p_status text | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_platform_business_period_summary | mart | FUNCTION | platform | p_platform_code text, p_start_date date, p_end_date date, p_scope_key text | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_platform_diagnostic_snapshot | mart | FUNCTION | diagnostic | p_platform_code text, p_start_date date, p_end_date date, p_scope_key text | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_price_band_period_summary | mart | FUNCTION | price_band | p_shop_name text, p_start_date date, p_end_date date, p_price_band text | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_product_contribution | mart | FUNCTION | product | p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_produ | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_product_period_summary | mart | FUNCTION | product | p_shop_name text, p_start_date date, p_end_date date, p_product_id text, p_produ | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_shop_contribution | mart | FUNCTION | catalog | p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_me | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.get_terminal_period_summary | mart | FUNCTION | terminal | p_shop_name text, p_start_date date, p_end_date date, p_terminal_type text, p_se | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.product_mapping_conflicts | mart | TABLE/VIEW | product |  | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.rank_accounts | mart | FUNCTION | account | p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metri | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.rank_audiences | mart | FUNCTION | audience | p_shop_name text, p_start_date date, p_end_date date, p_carrier_type text, p_met | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.rank_carriers | mart | FUNCTION | carrier | p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metri | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.rank_categories | mart | FUNCTION | catalog | p_shop_name text, p_start_date date, p_end_date date, p_category_level integer,  | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.rank_price_bands | mart | FUNCTION | price_band | p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_sort_ | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.rank_products | mart | FUNCTION | product | p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_sort_ | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.resolve_master_product | mart | FUNCTION | product | p_platform_code text, p_shop_name text, p_platform_product_id text, p_biz_date d | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| mart.unmapped_products | mart | TABLE/VIEW | product |  | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| meta.master_product | meta | TABLE/VIEW | masterdata |  | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| meta.platform_product_mapping | meta | TABLE/VIEW | masterdata |  | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| meta.product_line | meta | TABLE/VIEW | masterdata |  | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |
| meta.shop | meta | TABLE/VIEW | masterdata |  | agent_readonly | ✅ | HTTP_NEEDS_WRAPPER | ACTIVE |