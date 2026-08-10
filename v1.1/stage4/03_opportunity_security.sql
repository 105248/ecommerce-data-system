-- ============================================================================
-- V1.1 阶段4｜增长机会发现与机会评分（多店兼容修订版）
-- 03_opportunity_security.sql（安全层）
-- ============================================================================
-- agent_readonly 只查（get_growth_opportunities / get_entity_opportunity / get_opportunity_summary）
-- 不执行 persist（detect_growth_opportunities 写入事件）
-- ============================================================================

-- get_entity_opportunity（单实体机会）
DROP FUNCTION IF EXISTS mart.get_entity_opportunity(text,text,text,date,date);
CREATE FUNCTION mart.get_entity_opportunity(
    p_platform_code text,
    p_domain_key    text,
    p_entity_name   text,
    p_start_date    date DEFAULT NULL,
    p_end_date      date DEFAULT NULL
) RETURNS TABLE (
    platform_code text, shop_name text, domain_key text, entity_level text,
    entity_name text, scope_key text, opportunity_code text, opportunity_name_cn text,
    current_start_date date, current_end_date date,
    current_value numeric, previous_value numeric, relative_change numeric,
    opportunity_score numeric, opportunity_level text, available_weight numeric,
    benchmark_peer_count integer, benchmark_p50 numeric, benchmark_p75 numeric,
    coverage_complete boolean, risk_flags text, status text, created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $f$
    SELECT e.platform_code, e.shop_name, e.domain_key, e.entity_level,
           e.entity_name, e.scope_key, e.opportunity_code, t.opportunity_name_cn,
           e.current_start_date, e.current_end_date,
           e.current_value, e.previous_value, e.relative_change,
           e.opportunity_score, e.opportunity_level, e.available_weight,
           e.benchmark_peer_count, e.benchmark_p50, e.benchmark_p75,
           e.coverage_complete, e.risk_flags, e.status, e.created_at
    FROM mart.opportunity_event e
    JOIN mart.opportunity_type t ON t.opportunity_code = e.opportunity_code
    WHERE e.platform_code = p_platform_code
      AND e.domain_key = p_domain_key
      AND e.entity_name = p_entity_name
      AND (p_start_date IS NULL OR e.current_start_date = p_start_date)
      AND (p_end_date IS NULL OR e.current_end_date = p_end_date)
    ORDER BY e.opportunity_score DESC;
$f$;

-- 权限
REVOKE ALL ON FUNCTION mart.detect_growth_opportunities(text,date,date,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_growth_opportunities(text,date,date,text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_entity_opportunity(text,text,text,date,date) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_opportunity_summary(text,date,date,text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION mart.get_growth_opportunities(text,date,date,text,text,text) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_entity_opportunity(text,text,text,date,date) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_opportunity_summary(text,date,date,text) TO agent_readonly;
-- 检测函数不授权 agent_readonly（写入事件）

GRANT SELECT ON mart.opportunity_event, mart.opportunity_type, mart.opportunity_rule TO agent_readonly;

COMMENT ON FUNCTION mart.get_entity_opportunity(text,text,text,date,date) IS 'V1.1 单实体机会（域+实体名过滤）。';
