-- ============================================================================
-- V1.1 阶段2｜异常检测引擎（多店兼容修订版）
-- 02_detect_anomalies.sql（核心检测 + 查询函数）
-- ============================================================================
-- 检测链：Snapshot → support → coverage → mapping → low-base → threshold → persistence → severity → event
-- 幂等：唯一键 (platform,shop,domain,entity,scope,metric,type,period,rule_version) 防重复
-- 安全：SECURITY DEFINER + 固定 search_path；agent_readonly 仅查询（get_anomalies 等），不执行 persist
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 核心检测：对指定 domain 的全部实体 × 8 类规则检测
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.detect_anomalies(text,date,date,text,text);
CREATE FUNCTION mart.detect_anomalies(
    p_platform_code text,
    p_start_date    date,
    p_end_date      date,
    p_domain_key    text,
    p_shop_name     text DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $function$
DECLARE
    v_ps date; v_pe date; v_days int;
    v_event_count int := 0;
    v_shop_cov bool; v_map_cov bool;
    r_rule record;
    r_ent record;
    v_cur numeric; v_prev numeric; v_rel numeric; v_pp numeric;
    v_base numeric; v_status text;
    v_sev_score numeric; v_sev text;
    v_prev_events int; v_consec int;
    v_chain text;
    v_plat_enabled int; v_plat_covered int; v_plat_complete bool;
    v_shop_enabled int; v_shop_covered int; v_shop_complete bool;
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL OR p_start_date > p_end_date THEN
        RAISE EXCEPTION '非法日期区间: % ~ %', p_start_date, p_end_date;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM mart.diagnostic_entity_rule WHERE domain_key = p_domain_key AND enabled) THEN
        RAISE EXCEPTION '未知/未启用诊断域: %', p_domain_key;
    END IF;
    v_days := (p_end_date - p_start_date) + 1;
    v_pe := p_start_date - 1;
    v_ps := v_pe - (v_days - 1);
    v_chain := 'S1|' || p_domain_key || '|' || p_platform_code;

    IF p_domain_key = 'platform' THEN
        CREATE TEMP TABLE snap_rows ON COMMIT DROP AS
        SELECT entity_id::text AS entity_id, entity_name::text AS entity_name, scope_key,
               metric_key, current_value, previous_value, relative_change, percentage_point_change,
               data_status, current_coverage_complete AS coverage_complete
        FROM mart.get_platform_diagnostic_snapshot(p_platform_code, p_start_date, p_end_date, '全店');
    ELSE
        CREATE TEMP TABLE snap_rows ON COMMIT DROP AS
        SELECT entity_id, entity_name, scope_key,
               metric_key, current_value, previous_value, relative_change, percentage_point_change,
               data_status, current_coverage_complete AS coverage_complete
        FROM mart.get_diagnostic_snapshot(p_shop_name, p_start_date, p_end_date, p_domain_key, NULL, NULL, NULL, NULL);
    END IF;

    -- 平台/店铺覆盖信息
    IF p_domain_key = 'platform' THEN
        SELECT enabled_shop_count, covered_shop_count, coverage_complete INTO v_plat_enabled, v_plat_covered, v_plat_complete
        FROM mart.get_platform_business_period_summary(p_platform_code, p_start_date, p_end_date, '全店');
    END IF;

    FOR r_rule IN SELECT * FROM mart.anomaly_rule WHERE enabled ORDER BY rule_code LOOP
        -- 域×指标支持检查（不支持跳过）
        IF NOT EXISTS (SELECT 1 FROM mart.get_diagnostic_entity_metrics(p_domain_key) m WHERE m.metric_key = r_rule.metric_key) THEN
            CONTINUE;
        END IF;

        FOR r_ent IN
            SELECT DISTINCT entity_id, entity_name, scope_key FROM snap_rows
            WHERE metric_key = r_rule.metric_key
        LOOP
            SELECT current_value, previous_value, relative_change, percentage_point_change, data_status
              INTO v_cur, v_prev, v_rel, v_pp, v_status
            FROM snap_rows
            WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
              AND metric_key = r_rule.metric_key
              AND scope_key IS NOT DISTINCT FROM r_ent.scope_key
            LIMIT 1;
            IF v_cur IS NULL AND v_prev IS NULL THEN CONTINUE; END IF;

            -- coverage 优先级（文档十三节）：NO DATA → COVERAGE → UNSUPPORTED → LOW BASE → THRESHOLD
            IF v_status IN ('NO_CURRENT_DATA','NO_PREVIOUS_DATA','CURRENT_INCOMPLETE','PREVIOUS_INCOMPLETE','BOTH_INCOMPLETE') THEN
                CONTINUE;  -- 数据不完整不判异常（平台缺店 → COVERAGE_INCOMPLETE 语义）
            END IF;
            -- 平台 coverage 不完整 → 不判异常
            IF p_domain_key = 'platform' AND NOT v_plat_complete THEN
                CONTINUE;
            END IF;
            IF v_prev IS NULL OR v_prev = 0 THEN CONTINUE; END IF;  -- PREVIOUS_ZERO / 无上期 → 不判

            -- 低基数（base 用该指标行 current 值；ratio 类用对应数量指标）
            v_base := v_cur;
            IF r_rule.low_base_metric IS NOT NULL AND r_rule.low_base_metric <> r_rule.metric_key THEN
                SELECT current_value INTO v_base FROM snap_rows
                WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
                  AND metric_key = r_rule.low_base_metric
                  AND scope_key IS NOT DISTINCT FROM r_ent.scope_key
                LIMIT 1;
            END IF;
            IF v_base IS NULL OR v_base < r_rule.low_base_value THEN CONTINUE; END IF;  -- LOW BASE

            -- 阈值判断
            IF r_rule.metric_direction = 'DROP' THEN
                IF r_rule.metric_key IN ('refund_rate_pay_time','exposure_to_click_rate_users','click_to_transaction_rate_users','ad_attributed_transaction_share','ad_spend_rate_net_refund_shop_bound') THEN
                    -- ratio 指标用百分点
                    IF v_pp IS NULL OR (-v_pp) < coalesce(r_rule.threshold_pp, 0.02) THEN CONTINUE; END IF;
                ELSE
                    IF v_rel IS NULL OR (-v_rel) < r_rule.threshold_relative THEN CONTINUE; END IF;
                END IF;
            ELSE  -- RISE
                IF r_rule.metric_key = 'refund_rate_pay_time' THEN
                    IF v_pp IS NULL OR v_pp < coalesce(r_rule.threshold_pp, 0.02) THEN CONTINUE; END IF;
                ELSE
                    IF v_rel IS NULL OR v_rel < r_rule.threshold_relative THEN CONTINUE; END IF;
                END IF;
            END IF;

            -- persistence：查历史同实体同类型事件
            SELECT count(*) INTO v_prev_events FROM mart.anomaly_event
            WHERE domain_key = p_domain_key AND entity_id IS NOT DISTINCT FROM r_ent.entity_id
              AND anomaly_type = r_rule.rule_code AND status <> 'RESOLVED';
            v_consec := least(v_prev_events + 1, 30);

            -- severity：magnitude + materiality + persistence + data_quality
            v_sev_score := r_rule.severity_base
                + least(abs(coalesce(v_rel, 0)) * 100, 20)
                + least(abs(coalesce(v_pp, 0)) * 400, 10)
                + least(v_consec * 3, 15);
            IF p_domain_key = 'platform' AND NOT v_plat_complete THEN v_sev_score := v_sev_score - 15; END IF;
            v_sev_score := greatest(v_sev_score, 0);
            IF v_sev_score >= 80 THEN v_sev := 'CRITICAL';
            ELSIF v_sev_score >= 65 THEN v_sev := 'HIGH';
            ELSIF v_sev_score >= 50 THEN v_sev := 'MEDIUM';
            ELSIF v_sev_score >= 35 THEN v_sev := 'LOW';
            ELSE v_sev := 'INFO'; END IF;

            -- 生成事件（幂等：唯一键冲突自动跳过）
            INSERT INTO mart.anomaly_event
                (platform_code, shop_name, domain_key, entity_level, entity_id, entity_name, scope_key,
                 metric_key, anomaly_type, current_start_date, current_end_date, previous_start_date, previous_end_date,
                 current_value, previous_value, absolute_change, relative_change, percentage_point_change,
                 low_base_value, materiality, triggered_period_count, consecutive_day_count,
                 severity, severity_score, coverage_complete, shop_coverage_complete, mapping_complete,
                 data_quality_score, diagnostic_chain_key, status, rule_version, notes)
            VALUES
                (p_platform_code,
                 CASE WHEN p_domain_key = 'platform' THEN NULL ELSE p_shop_name END,
                 p_domain_key, p_domain_key, r_ent.entity_id, r_ent.entity_name, r_ent.scope_key,
                 r_rule.metric_key, r_rule.rule_code,
                 p_start_date, p_end_date, v_ps, v_pe,
                 v_cur, v_prev, (v_cur - v_prev), v_rel, v_pp,
                 r_rule.low_base_value, abs(v_cur - v_prev),
                 v_prev_events + 1, v_consec,
                 v_sev, v_sev_score,
                 (v_status = 'OK'), v_plat_complete, NULL,
                 CASE WHEN v_status = 'OK' THEN 90 ELSE 60 END,
                 v_chain, 'OPEN', 'v1',
                 '多店兼容异常检测（' || r_rule.rule_name_cn || '）')
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;

    DROP TABLE IF EXISTS snap_rows;
    RETURN (SELECT count(*)::int FROM mart.anomaly_event
            WHERE current_start_date = p_start_date AND current_end_date = p_end_date
              AND domain_key = p_domain_key AND platform_code = p_platform_code);
END;
$function$;

COMMENT ON FUNCTION mart.detect_anomalies(text,date,date,text,text) IS
'V1.1 异常检测（多店兼容）：对指定域全部实体×8类规则检测，幂等写 anomaly_event。
检测链=快照→支持→coverage→低基数→阈值→持续性→严重度→事件。';

-- ----------------------------------------------------------------------------
-- 2. 查询函数（agent_readonly 可执行）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.get_anomalies(text,date,date,text,text,text,text);
CREATE FUNCTION mart.get_anomalies(
    p_platform_code text DEFAULT 'douyin',
    p_start_date    date DEFAULT NULL,
    p_end_date      date DEFAULT NULL,
    p_domain_key    text DEFAULT NULL,
    p_entity_name   text DEFAULT NULL,
    p_severity      text DEFAULT NULL,
    p_status        text DEFAULT 'OPEN'
) RETURNS TABLE (
    platform_code text, shop_name text, domain_key text, entity_level text,
    entity_id text, entity_name text, scope_key text,
    metric_key text, anomaly_type text, anomaly_name_cn text,
    current_start_date date, current_end_date date,
    previous_start_date date, previous_end_date date,
    current_value numeric, previous_value numeric,
    absolute_change numeric, relative_change numeric, percentage_point_change numeric,
    triggered_period_count integer, consecutive_day_count integer,
    severity text, severity_score numeric,
    coverage_complete boolean, shop_coverage_complete boolean, mapping_complete boolean,
    materiality numeric, diagnostic_chain_key text, status text, created_at timestamptz
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
           e.previous_start_date, e.previous_end_date,
           e.current_value, e.previous_value,
           e.absolute_change, e.relative_change, e.percentage_point_change,
           e.triggered_period_count, e.consecutive_day_count,
           e.severity, e.severity_score,
           e.coverage_complete, e.shop_coverage_complete, e.mapping_complete,
           e.materiality, e.diagnostic_chain_key, e.status, e.created_at
    FROM mart.anomaly_event e
    JOIN mart.anomaly_rule r ON r.rule_code = e.anomaly_type
    WHERE e.platform_code = p_platform_code
      AND (p_start_date IS NULL OR e.current_start_date = p_start_date)
      AND (p_end_date IS NULL OR e.current_end_date = p_end_date)
      AND (p_domain_key IS NULL OR e.domain_key = p_domain_key)
      AND (p_entity_name IS NULL OR e.entity_name = p_entity_name)
      AND (p_severity IS NULL OR e.severity = p_severity)
      AND (p_status IS NULL OR e.status = p_status)
    ORDER BY e.severity_score DESC, e.current_end_date DESC;
$f$;

COMMENT ON FUNCTION mart.get_anomalies(text,date,date,text,text,text,text) IS 'V1.1 异常查询（按平台/区间/域/实体/严重度/状态过滤）。';

DROP FUNCTION IF EXISTS mart.get_anomaly_summary(text,date,date,text);
CREATE FUNCTION mart.get_anomaly_summary(
    p_platform_code text DEFAULT 'douyin',
    p_start_date    date DEFAULT NULL,
    p_end_date      date DEFAULT NULL,
    p_status        text DEFAULT 'OPEN'
) RETURNS TABLE (
    domain_key text, anomaly_type text, anomaly_name_cn text,
    event_count bigint, severity text,
    total_materiality numeric, avg_relative_change numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $f$
    SELECT e.domain_key, e.anomaly_type, r.rule_name_cn,
           count(*)::bigint AS event_count,
           max(e.severity) AS severity,
           sum(e.materiality) AS total_materiality,
           avg(e.relative_change) AS avg_relative_change
    FROM mart.anomaly_event e
    JOIN mart.anomaly_rule r ON r.rule_code = e.anomaly_type
    WHERE e.platform_code = p_platform_code
      AND (p_start_date IS NULL OR e.current_start_date = p_start_date)
      AND (p_end_date IS NULL OR e.current_end_date = p_end_date)
      AND (p_status IS NULL OR e.status = p_status)
    GROUP BY e.domain_key, e.anomaly_type, r.rule_name_cn
    ORDER BY event_count DESC;
$f$;

COMMENT ON FUNCTION mart.get_anomaly_summary(text,date,date,text) IS 'V1.1 异常汇总（按域×类型统计事件数/严重度/影响额）。';

-- ----------------------------------------------------------------------------
-- 3. 幂等控制：RESOLVED / SUPPRESSED（agent_readonly 不可执行——仅 postgres/管理员）
-- ----------------------------------------------------------------------------
