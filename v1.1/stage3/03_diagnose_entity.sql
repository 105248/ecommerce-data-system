-- ============================================================================
-- V1.1 阶段3｜问题定位与漏斗诊断（多店兼容修订版）
-- 03_diagnose_entity.sql（实体诊断主函数 + 异常入口诊断 + 安全层）
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 实体诊断主函数：快照 + 漏斗环节 + primary_stage + 置信度 + 证据链 → diagnostic_result
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.diagnose_entity(text,text,date,date,text,text,bigint);
CREATE FUNCTION mart.diagnose_entity(
    p_domain_key       text,
    p_entity_name      text,
    p_start_date       date,
    p_end_date         date,
    p_shop_name        text DEFAULT NULL,
    p_scope_key        text DEFAULT NULL,
    p_anomaly_event_id bigint DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $function$
DECLARE
    v_ps date; v_pe date; v_days int;
    v_up_cur numeric; v_up_prev numeric; v_up_rel numeric;
    v_exp_cur numeric; v_click_cur numeric; v_conv_cur numeric; v_refund_cur numeric;
    v_exp_rel numeric; v_click_rel numeric; v_conv_rel numeric; v_refund_rel numeric;
    v_primary text := 'unknown';
    v_diag_code text := 'D01_SALES_DECLINE';
    v_status text := 'DIAGNOSED';
    v_conf numeric := 0;
    v_neg_stages int := 0;
    v_evidence jsonb; v_path jsonb;
    v_chain text;
    v_id bigint;
    r record;
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

    -- 快照取该实体各指标
    FOR r IN
        SELECT metric_key, current_value, previous_value, relative_change, data_status, current_coverage_complete
        FROM mart.get_diagnostic_snapshot(p_shop_name, p_start_date, p_end_date, p_domain_key, p_scope_key,
                                          CASE WHEN p_domain_key='product_line' THEN NULL ELSE p_entity_name END,
                                          CASE WHEN p_domain_key='product_line' THEN p_entity_name ELSE NULL END,
                                          NULL)
        WHERE entity_name = p_entity_name OR entity_id = p_entity_name
    LOOP
        IF r.metric_key = 'user_pay_amount' THEN
            v_up_cur := r.current_value; v_up_prev := r.previous_value; v_up_rel := r.relative_change;
        ELSIF r.metric_key = 'product_exposure_user_count' THEN
            v_exp_cur := r.current_value; v_exp_rel := r.relative_change;
        ELSIF r.metric_key = 'product_click_user_count' THEN
            v_click_cur := r.current_value; v_click_rel := r.relative_change;
        ELSIF r.metric_key = 'transaction_buyer_count' THEN
            v_conv_cur := r.current_value; v_conv_rel := r.relative_change;
        ELSIF r.metric_key = 'refund_rate_pay_time' THEN
            v_refund_cur := r.current_value; v_refund_rel := r.relative_change;
        END IF;
    END LOOP;

    -- 无数据 → NO_CONFIRMED_ANOMALY / COVERAGE
    IF v_up_cur IS NULL AND v_up_prev IS NULL THEN
        INSERT INTO mart.diagnostic_result
            (platform_code, shop_name, domain_key, entity_level, entity_id, entity_name, scope_key,
             diagnostic_code, primary_stage, diagnostic_status,
             current_start_date, current_end_date, previous_start_date, previous_end_date,
             confidence_score, evidence_json, path_json, diagnostic_chain_id, source_anomaly_event_id,
             coverage_complete, mapping_complete, notes, created_at)
        VALUES
            ('douyin', p_shop_name, p_domain_key, p_domain_key, NULL, p_entity_name, p_scope_key,
             NULL, 'unknown', 'NO_CONFIRMED_ANOMALY',
             p_start_date, p_end_date, v_ps, v_pe,
             0, '{}'::jsonb, jsonb_build_array(jsonb_build_object('domain', p_domain_key, 'entity', p_entity_name)),
             NULL, p_anomaly_event_id, NULL, NULL, '无当前/上期数据，不构成可诊断异常', now())
        RETURNING diagnostic_id INTO v_id;
        RETURN v_id;
    END IF;

    -- primary_stage：最负向环节（漏斗优先）
    v_neg_stages := 0;
    IF v_exp_rel IS NOT NULL AND v_exp_rel < -0.05 THEN v_neg_stages := v_neg_stages + 1; v_primary := 'traffic'; END IF;
    IF v_click_rel IS NOT NULL AND v_click_rel < -0.05 THEN v_neg_stages := v_neg_stages + 1; IF v_primary = 'unknown' THEN v_primary := 'click'; END IF; END IF;
    IF v_conv_rel IS NOT NULL AND v_conv_rel < -0.05 THEN v_neg_stages := v_neg_stages + 1; IF v_primary = 'unknown' THEN v_primary := 'conversion'; END IF; END IF;
    IF v_refund_rel IS NOT NULL AND v_refund_rel > 0.05 THEN v_neg_stages := v_neg_stages + 1; IF v_primary = 'unknown' THEN v_primary := 'refund'; END IF; END IF;
    IF v_neg_stages >= 2 THEN
        v_status := 'MULTI_FACTOR'; v_diag_code := 'D08_MULTI_FACTOR_DECLINE';
    ELSIF v_up_rel IS NOT NULL AND v_up_rel < 0 THEN
        v_diag_code := CASE v_primary
            WHEN 'traffic' THEN 'D02_TRAFFIC_DECLINE'
            WHEN 'click' THEN 'D03_CLICK_FUNNEL_DECLINE'
            WHEN 'conversion' THEN 'D04_CONVERSION_FUNNEL_DECLINE'
            WHEN 'refund' THEN 'D05_REFUND_DETERIORATION'
            ELSE 'D01_SALES_DECLINE' END;
        IF v_primary = 'unknown' THEN v_primary := 'conversion'; END IF;
    ELSIF v_up_rel IS NOT NULL AND v_up_rel >= 0 THEN
        v_status := 'NO_CONFIRMED_ANOMALY';
    END IF;

    -- 置信度（evidence 完整度 + coverage）
    v_conf := 0;
    IF v_up_cur IS NOT NULL THEN v_conf := v_conf + 20; END IF;
    IF v_up_prev IS NOT NULL THEN v_conf := v_conf + 20; END IF;
    IF v_exp_rel IS NOT NULL THEN v_conf := v_conf + 15; END IF;
    IF v_click_rel IS NOT NULL THEN v_conf := v_conf + 15; END IF;
    IF v_conv_rel IS NOT NULL THEN v_conf := v_conf + 15; END IF;
    IF v_refund_rel IS NOT NULL THEN v_conf := v_conf + 15; END IF;

    v_chain := 'D3|' || p_domain_key || '|' || coalesce(p_entity_name, '') || '|' || p_start_date || '~' || p_end_date;
    v_evidence := jsonb_build_object(
        'current', v_up_cur, 'previous', v_up_prev, 'relative_change', v_up_rel,
        'funnel', jsonb_build_object('traffic_rel', v_exp_rel, 'click_rel', v_click_rel,
                                      'conversion_rel', v_conv_rel, 'refund_rel', v_refund_rel),
        'coverage_complete', true);
    v_path := jsonb_build_array(jsonb_build_object('domain', p_domain_key, 'entity', p_entity_name));

    INSERT INTO mart.diagnostic_result
        (platform_code, shop_name, domain_key, entity_level, entity_id, entity_name, scope_key,
         diagnostic_code, primary_stage, diagnostic_status,
         current_start_date, current_end_date, previous_start_date, previous_end_date,
         current_value, previous_value, absolute_change, relative_change,
         confidence_score, evidence_json, path_json, diagnostic_chain_id, source_anomaly_event_id,
         coverage_complete, mapping_complete, notes, created_at)
    VALUES
        ('douyin', p_shop_name, p_domain_key, p_domain_key, NULL, p_entity_name, p_scope_key,
         v_diag_code, v_primary, v_status,
         p_start_date, p_end_date, v_ps, v_pe,
         v_up_cur, v_up_prev, (v_up_cur - v_up_prev), v_up_rel,
         v_conf, v_evidence, v_path, v_chain, p_anomaly_event_id,
         true, NULL, '数据层问题定位（漏斗/贡献/投放拆解）', now())
    RETURNING diagnostic_id INTO v_id;
    RETURN v_id;
END;
$function$;

COMMENT ON FUNCTION mart.diagnose_entity(text,text,date,date,text,text,bigint) IS
'V1.1 实体诊断主函数：快照+漏斗环节→primary_stage→diagnostic_code→置信度→证据链→diagnostic_result。
多因素(MULTI_FACTOR)不强制唯一根因；无数据→NO_CONFIRMED_ANOMALY。';

-- ----------------------------------------------------------------------------
-- 2. 异常入口诊断（从 anomaly_event 触发）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.diagnose_anomaly(bigint);
CREATE FUNCTION mart.diagnose_anomaly(p_anomaly_event_id bigint)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $function$
DECLARE
    v_ev record; v_id bigint;
BEGIN
    SELECT * INTO v_ev FROM mart.anomaly_event WHERE anomaly_event_id = p_anomaly_event_id;
    IF v_ev IS NULL THEN RAISE EXCEPTION '异常事件不存在: %', p_anomaly_event_id; END IF;
    v_id := mart.diagnose_entity(v_ev.domain_key, coalesce(v_ev.entity_name, '抖音整体'),
                                 v_ev.current_start_date, v_ev.current_end_date,
                                 v_ev.shop_name, v_ev.scope_key, p_anomaly_event_id);
    RETURN v_id;
END;
$function$;

COMMENT ON FUNCTION mart.diagnose_anomaly(bigint) IS 'V1.1 从异常事件入口生成诊断（Stage2 异常 → Stage3 定位）。';

-- ----------------------------------------------------------------------------
-- 3. 查询诊断结果
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.get_diagnostic_result(text,date,date,text,text);
CREATE FUNCTION mart.get_diagnostic_result(
    p_platform_code text DEFAULT 'douyin',
    p_start_date    date DEFAULT NULL,
    p_end_date      date DEFAULT NULL,
    p_domain_key    text DEFAULT NULL,
    p_status        text DEFAULT NULL
) RETURNS TABLE (
    diagnostic_id bigint, platform_code text, shop_name text, domain_key text, entity_level text,
    entity_name text, scope_key text, diagnostic_code text, diagnostic_name_cn text,
    primary_stage text, diagnostic_status text,
    current_start_date date, current_end_date date,
    current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric,
    confidence_score numeric, evidence_json jsonb, path_json jsonb, diagnostic_chain_id text,
    coverage_complete boolean, mapping_complete boolean, created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $f$
    SELECT d.diagnostic_id, d.platform_code, d.shop_name, d.domain_key, d.entity_level,
           d.entity_name, d.scope_key, d.diagnostic_code, t.diagnostic_name_cn,
           d.primary_stage, d.diagnostic_status,
           d.current_start_date, d.current_end_date,
           d.current_value, d.previous_value, d.absolute_change, d.relative_change,
           d.confidence_score, d.evidence_json, d.path_json, d.diagnostic_chain_id,
           d.coverage_complete, d.mapping_complete, d.created_at
    FROM mart.diagnostic_result d
    LEFT JOIN mart.diagnostic_type t ON t.diagnostic_code = d.diagnostic_code
    WHERE d.platform_code = p_platform_code
      AND (p_start_date IS NULL OR d.current_start_date = p_start_date)
      AND (p_end_date IS NULL OR d.current_end_date = p_end_date)
      AND (p_domain_key IS NULL OR d.domain_key = p_domain_key)
      AND (p_status IS NULL OR d.diagnostic_status = p_status)
    ORDER BY d.diagnostic_id DESC;
$f$;

-- ----------------------------------------------------------------------------
-- 4. 安全层：agent_readonly 只读诊断结果（不执行 diagnose 写入）
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION mart.diagnose_entity(text,text,date,date,text,text,bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.diagnose_anomaly(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_diagnostic_result(text,date,date,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.decompose_master_product_by_shop_product(bigint,date,date) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_funnel_diagnosis(text,text,date,date,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_advertising_diagnosis(text,text,date,date,text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION mart.get_diagnostic_result(text,date,date,text,text) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.decompose_master_product_by_shop_product(bigint,date,date) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_funnel_diagnosis(text,text,date,date,text,text) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_advertising_diagnosis(text,text,date,date,text) TO agent_readonly;
GRANT SELECT ON mart.diagnostic_result, mart.diagnostic_type TO agent_readonly;
