-- ============================================================================
-- V1.1 阶段2｜异常检测引擎（多店兼容修订版）
-- 03_anomaly_security.sql（安全层 + get_entity_anomalies）
-- ============================================================================
-- agent_readonly 只执行查询：get_anomalies / get_entity_anomalies / get_anomaly_summary
-- 不执行 persist（detect_anomalies）——写事件由 postgres/管理员执行
-- ============================================================================

-- get_entity_anomalies（单实体异常）
DROP FUNCTION IF EXISTS mart.get_entity_anomalies(text,text,text,date,date);
CREATE FUNCTION mart.get_entity_anomalies(
    p_platform_code text,
    p_domain_key    text,
    p_entity_name   text,
    p_start_date    date DEFAULT NULL,
    p_end_date      date DEFAULT NULL
) RETURNS TABLE (
    platform_code text, shop_name text, domain_key text, entity_level text,
    entity_id text, entity_name text, scope_key text,
    metric_key text, anomaly_type text, anomaly_name_cn text,
    current_start_date date, current_end_date date,
    current_value numeric, previous_value numeric,
    absolute_change numeric, relative_change numeric, percentage_point_change numeric,
    triggered_period_count integer, consecutive_day_count integer,
    severity text, severity_score numeric,
    coverage_complete boolean, shop_coverage_complete boolean, mapping_complete boolean,
    materiality numeric, status text, created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $f$
    SELECT e.platform_code, e.shop_name, e.domain_key, e.entity_level,
           e.entity_id, e.entity_name, e.scope_key,
           e.metric_key, e.anomaly_type, r.rule_name_cn,
           e.current_start_date, e.current_end_date,
           e.current_value, e.previous_value,
           e.absolute_change, e.relative_change, e.percentage_point_change,
           e.triggered_period_count, e.consecutive_day_count,
           e.severity, e.severity_score,
           e.coverage_complete, e.shop_coverage_complete, e.mapping_complete,
           e.materiality, e.status, e.created_at
    FROM mart.anomaly_event e
    JOIN mart.anomaly_rule r ON r.rule_code = e.anomaly_type
    WHERE e.platform_code = p_platform_code
      AND e.domain_key = p_domain_key
      AND e.entity_name = p_entity_name
      AND (p_start_date IS NULL OR e.current_start_date = p_start_date)
      AND (p_end_date IS NULL OR e.current_end_date = p_end_date)
    ORDER BY e.severity_score DESC;
$f$;

-- 权限
REVOKE ALL ON FUNCTION mart.detect_anomalies(text,date,date,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_anomalies(text,date,date,text,text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_entity_anomalies(text,text,text,date,date) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_anomaly_summary(text,date,date,text) FROM PUBLIC;

-- agent_readonly 仅查询 3 个（不执行 detect_anomalies）
GRANT EXECUTE ON FUNCTION mart.get_anomalies(text,date,date,text,text,text,text) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_entity_anomalies(text,text,text,date,date) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_anomaly_summary(text,date,date,text) TO agent_readonly;
-- 检测函数不授权 agent_readonly（写入事件）

-- 事件表：agent_readonly 可读
GRANT SELECT ON mart.anomaly_event, mart.anomaly_rule TO agent_readonly;

COMMENT ON FUNCTION mart.get_entity_anomalies(text,text,text,date,date) IS 'V1.1 单实体异常查询（域+实体名过滤）。';
