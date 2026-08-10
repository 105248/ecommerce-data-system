-- ============================================================================
-- V1.1 阶段4｜增长机会发现与机会评分（多店兼容修订版）
-- 02_detect_opportunities.sql（机会检测 + 查询）
-- ============================================================================
-- Peer 分池：同域同 scope 全部实体（shop vs shop / MP vs MP / 品线 vs 品线），median/P75。
-- 7 维评分（growth/persistence/conversion/refund/ad_eff/materiality/contribution）× 权重 20/20/20/15/10/10/5
-- 缺失维度重归一（available_weight >= 70% 否则 INSUFFICIENT_EVIDENCE）
-- ============================================================================

DROP FUNCTION IF EXISTS mart.detect_growth_opportunities(text,date,date,text,text);
CREATE FUNCTION mart.detect_growth_opportunities(
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
    r_ent record; v_rule record;
    v_up_cur numeric; v_up_prev numeric; v_up_rel numeric;
    v_cvr_cur numeric; v_cvr_rel numeric; v_ctr_rel numeric;
    v_refund_cur numeric; v_refund_rel numeric;
    v_eff_rel numeric; v_spend_cur numeric; v_spend_rel numeric;
    v_exp_cur numeric;
    v_score numeric; v_level text; v_avail numeric;
    v_peer_p50 numeric; v_peer_p75 numeric; v_peer_count int;
    v_status text; v_code text; v_flags text;
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL OR p_start_date > p_end_date THEN
        RAISE EXCEPTION '非法日期区间: % ~ %', p_start_date, p_end_date;
    END IF;
    v_days := (p_end_date - p_start_date) + 1;
    v_pe := p_start_date - 1;
    v_ps := v_pe - (v_days - 1);

    IF p_domain_key = 'platform' THEN
        CREATE TEMP TABLE snap_rows ON COMMIT DROP AS
        SELECT entity_id::text AS entity_id, entity_name::text AS entity_name, scope_key, metric_key,
               current_value, previous_value, relative_change, data_status
        FROM mart.get_platform_diagnostic_snapshot(p_platform_code, p_start_date, p_end_date, '全店');
    ELSE
        CREATE TEMP TABLE snap_rows ON COMMIT DROP AS
        SELECT entity_id, entity_name, scope_key, metric_key,
               current_value, previous_value, relative_change, data_status
        FROM mart.get_diagnostic_snapshot(p_shop_name, p_start_date, p_end_date, p_domain_key, NULL, NULL, NULL, NULL);
    END IF;

    FOR r_ent IN SELECT DISTINCT entity_id, entity_name, scope_key FROM snap_rows LOOP
        -- 取指标
        SELECT current_value, previous_value, relative_change INTO v_up_cur, v_up_prev, v_up_rel
        FROM snap_rows WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
          AND scope_key IS NOT DISTINCT FROM r_ent.scope_key AND metric_key='user_pay_amount' LIMIT 1;
        SELECT current_value, relative_change INTO v_cvr_cur, v_cvr_rel
        FROM snap_rows WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
          AND scope_key IS NOT DISTINCT FROM r_ent.scope_key AND metric_key='click_to_transaction_rate_users' LIMIT 1;
        SELECT relative_change INTO v_ctr_rel FROM snap_rows WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
          AND scope_key IS NOT DISTINCT FROM r_ent.scope_key AND metric_key='exposure_to_click_rate_users' LIMIT 1;
        SELECT current_value, relative_change INTO v_refund_cur, v_refund_rel FROM snap_rows
          WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
          AND scope_key IS NOT DISTINCT FROM r_ent.scope_key AND metric_key='refund_rate_pay_time' LIMIT 1;
        SELECT relative_change INTO v_eff_rel FROM snap_rows WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
          AND scope_key IS NOT DISTINCT FROM r_ent.scope_key AND metric_key='ad_efficiency_shop_promoted' LIMIT 1;
        SELECT current_value, relative_change INTO v_spend_cur, v_spend_rel FROM snap_rows
          WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
          AND scope_key IS NOT DISTINCT FROM r_ent.scope_key AND metric_key='ad_spend_shop_promoted' LIMIT 1;
        SELECT current_value INTO v_exp_cur FROM snap_rows WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
          AND scope_key IS NOT DISTINCT FROM r_ent.scope_key AND metric_key='product_exposure_user_count' LIMIT 1;

        -- 状态判定
        v_status := 'QUALIFIED'; v_flags := '';
        IF v_up_cur IS NULL THEN CONTINUE; END IF;
        IF v_up_prev IS NULL OR v_up_prev = 0 THEN
            INSERT INTO mart.opportunity_event (platform_code, shop_name, domain_key, entity_level, entity_id, entity_name, scope_key,
                current_start_date, current_end_date, previous_start_date, previous_end_date, current_value, previous_value,
                relative_change, opportunity_score, opportunity_level, available_weight, status, notes, created_at)
            VALUES (p_platform_code, p_shop_name, p_domain_key, p_domain_key, r_ent.entity_id, r_ent.entity_name, r_ent.scope_key,
                p_start_date, p_end_date, v_ps, v_pe, v_up_cur, v_up_prev, NULL, 0, 'LOW', 0, 'NEW_BASE_SIGNAL',
                '上期=0，仅新基线信号（不判机会）', now()) ON CONFLICT DO NOTHING;
            CONTINUE;
        END IF;
        IF v_up_cur < 3000 THEN
            INSERT INTO mart.opportunity_event (platform_code, shop_name, domain_key, entity_level, entity_id, entity_name, scope_key,
                current_start_date, current_end_date, previous_start_date, previous_end_date, current_value, previous_value,
                relative_change, opportunity_score, opportunity_level, available_weight, status, notes, created_at)
            VALUES (p_platform_code, p_shop_name, p_domain_key, p_domain_key, r_ent.entity_id, r_ent.entity_name, r_ent.scope_key,
                p_start_date, p_end_date, v_ps, v_pe, v_up_cur, v_up_prev, v_up_rel, 0, 'LOW', 0, 'LOW_BASE',
                '成交规模低于低基数门槛3000（小样本高增不得判机会）', now()) ON CONFLICT DO NOTHING;
            CONTINUE;
        END IF;
        -- 平台 coverage（shop 覆盖）
        IF p_domain_key = 'platform' THEN
            v_status := 'QUALIFIED';
        END IF;

        -- Peer 池：同域同 scope 的 growth 分布
        SELECT count(*), percentile_cont(0.5) WITHIN GROUP (ORDER BY rel), percentile_cont(0.75) WITHIN GROUP (ORDER BY rel)
        INTO v_peer_count, v_peer_p50, v_peer_p75
        FROM (SELECT relative_change AS rel FROM snap_rows s2 WHERE s2.metric_key='user_pay_amount'
              AND s2.scope_key IS NOT DISTINCT FROM r_ent.scope_key AND s2.relative_change IS NOT NULL) t;
        IF v_peer_count < 3 THEN
            INSERT INTO mart.opportunity_event (platform_code, shop_name, domain_key, entity_level, entity_id, entity_name, scope_key,
                current_start_date, current_end_date, previous_start_date, previous_end_date, current_value, previous_value,
                relative_change, opportunity_score, opportunity_level, available_weight, benchmark_peer_count, status, notes, created_at)
            VALUES (p_platform_code, p_shop_name, p_domain_key, p_domain_key, r_ent.entity_id, r_ent.entity_name, r_ent.scope_key,
                p_start_date, p_end_date, v_ps, v_pe, v_up_cur, v_up_prev, v_up_rel, 0, 'LOW', 0, v_peer_count, 'INSUFFICIENT_PEERS',
                '同域 peer 不足3个，不得说高于同行', now()) ON CONFLICT DO NOTHING;
            CONTINUE;
        END IF;

        FOR v_rule IN SELECT * FROM mart.opportunity_rule WHERE rule_code IN (
            'O01_SUSTAINED_GROWTH','O02_CONVERSION_IMPROVEMENT','O03_TRAFFIC_SCALE_OPPORTUNITY',
            'O04_HIGH_EFFICIENCY_AD_OPPORTUNITY','O05_ORGANIC_GROWTH_OPPORTUNITY','O06_HEALTHY_LOW_REFUND_GROWTH',
            'O07_CHANNEL_EXPANSION_OPPORTUNITY','O08_CATEGORY_OR_PRODUCT_LINE_OPPORTUNITY') ORDER BY rule_code
        LOOP
            -- O 类型触发条件
            v_code := v_rule.rule_code;
            v_status := 'QUALIFIED'; v_flags := '';
            IF v_code = 'O01_SUSTAINED_GROWTH' AND (v_up_rel IS NULL OR v_up_rel < v_rule.min_growth) THEN CONTINUE; END IF;
            IF v_code = 'O02_CONVERSION_IMPROVEMENT' AND (v_cvr_rel IS NULL OR v_cvr_rel <= 0 OR v_ctr_rel IS NULL OR v_ctr_rel <= 0) THEN CONTINUE; END IF;
            IF v_code = 'O03_TRAFFIC_SCALE_OPPORTUNITY' AND (v_cvr_rel IS NULL OR v_cvr_rel < 0 OR v_exp_cur IS NULL OR v_exp_cur > coalesce(v_peer_p50, 0)) THEN CONTINUE; END IF;
            IF v_code = 'O04_HIGH_EFFICIENCY_AD_OPPORTUNITY' AND (v_eff_rel IS NULL OR v_eff_rel <= 0 OR coalesce(v_spend_cur,0) < 1000) THEN CONTINUE; END IF;
            IF v_code = 'O05_ORGANIC_GROWTH_OPPORTUNITY' AND (v_up_rel IS NULL OR v_up_rel < 0.15 OR coalesce(v_spend_rel, 0) > 0.05) THEN CONTINUE; END IF;
            IF v_code = 'O06_HEALTHY_LOW_REFUND_GROWTH' AND (v_up_rel IS NULL OR v_up_rel < 0.15 OR coalesce(v_refund_rel, 0) > 0.05) THEN CONTINUE; END IF;
            IF v_code = 'O07_CHANNEL_EXPANSION_OPPORTUNITY' AND p_domain_key NOT IN ('scope','carrier','shop','platform') THEN CONTINUE; END IF;
            IF v_code = 'O07_CHANNEL_EXPANSION_OPPORTUNITY' AND (v_up_rel IS NULL OR v_up_rel < 0.15) THEN CONTINUE; END IF;
            IF v_code = 'O08_CATEGORY_OR_PRODUCT_LINE_OPPORTUNITY' AND p_domain_key NOT IN ('product_line','category') THEN CONTINUE; END IF;
            IF v_code = 'O08_CATEGORY_OR_PRODUCT_LINE_OPPORTUNITY' AND (v_up_rel IS NULL OR v_up_rel < 0.15) THEN CONTINUE; END IF;

            -- 7 维评分（0-100）
            v_score := 0; v_avail := 0;
            -- growth
            IF v_up_rel IS NOT NULL THEN
                v_score := v_score + v_rule.weight_growth * greatest(0, least(v_up_rel * 3, 1));
                v_avail := v_avail + v_rule.weight_growth;
            END IF;
            -- persistence（增长为正即满分代理）
            IF v_up_rel IS NOT NULL THEN
                v_score := v_score + v_rule.weight_persistence * (CASE WHEN v_up_rel > 0 THEN 1 ELSE 0 END);
                v_avail := v_avail + v_rule.weight_persistence;
            END IF;
            -- conversion
            IF v_cvr_rel IS NOT NULL THEN
                v_score := v_score + v_rule.weight_conversion * greatest(0, least(v_cvr_rel * 3, 1));
                v_avail := v_avail + v_rule.weight_conversion;
            END IF;
            -- refund_health
            IF v_refund_rel IS NOT NULL THEN
                v_score := v_score + v_rule.weight_refund * greatest(0, least(1 - (v_refund_rel + 0.05) * 5, 1));
                v_avail := v_avail + v_rule.weight_refund;
                IF v_refund_rel > 0.1 THEN v_flags := v_flags || 'refund_risk;'; END IF;
            END IF;
            -- ad_efficiency
            IF v_eff_rel IS NOT NULL THEN
                v_score := v_score + v_rule.weight_ad_efficiency * greatest(0, least(v_eff_rel * 2, 1));
                v_avail := v_avail + v_rule.weight_ad_efficiency;
            END IF;
            -- materiality（成交规模对数归一：10万=满分）
            v_score := v_score + v_rule.weight_materiality * least(v_up_cur / 100000, 1);
            v_avail := v_avail + v_rule.weight_materiality;
            -- contribution（域内占比）
            IF (SELECT sum(current_value) FROM snap_rows WHERE metric_key='user_pay_amount' AND scope_key IS NOT DISTINCT FROM r_ent.scope_key) > 0 THEN
                v_score := v_score + v_rule.weight_contribution * least(
                    v_up_cur / (SELECT sum(current_value) FROM snap_rows WHERE metric_key='user_pay_amount' AND scope_key IS NOT DISTINCT FROM r_ent.scope_key) * 5, 1);
                v_avail := v_avail + v_rule.weight_contribution;
            END IF;

            -- 重归一
            IF v_avail < 70 THEN
                INSERT INTO mart.opportunity_event (platform_code, shop_name, domain_key, entity_level, entity_id, entity_name, scope_key,
                    opportunity_code, current_start_date, current_end_date, previous_start_date, previous_end_date,
                    current_value, previous_value, relative_change, opportunity_score, opportunity_level, available_weight, status, notes, created_at)
                VALUES (p_platform_code, p_shop_name, p_domain_key, p_domain_key, r_ent.entity_id, r_ent.entity_name, r_ent.scope_key,
                    v_code, p_start_date, p_end_date, v_ps, v_pe, v_up_cur, v_up_prev, v_up_rel,
                    0, 'LOW', v_avail, 'INSUFFICIENT_EVIDENCE', '可用维度权重不足70%（缺失维度过多）', now()) ON CONFLICT DO NOTHING;
                CONTINUE;
            END IF;
            v_score := v_score / v_avail * 100;
            IF v_score >= 85 THEN v_level := 'STRONG';
            ELSIF v_score >= 70 THEN v_level := 'HIGH';
            ELSIF v_score >= 50 THEN v_level := 'MEDIUM';
            ELSE v_level := 'LOW'; END IF;

            INSERT INTO mart.opportunity_event (platform_code, shop_name, domain_key, entity_level, entity_id, entity_name, scope_key,
                opportunity_code, current_start_date, current_end_date, previous_start_date, previous_end_date,
                current_value, previous_value, relative_change, growth_score, conversion_score, refund_score,
                opportunity_score, opportunity_level, available_weight,
                benchmark_pool, benchmark_peer_count, benchmark_p50, benchmark_p75,
                coverage_complete, risk_flags, diagnostic_chain_id, status, notes, created_at)
            VALUES (p_platform_code, p_shop_name, p_domain_key, p_domain_key, r_ent.entity_id, r_ent.entity_name, r_ent.scope_key,
                v_code, p_start_date, p_end_date, v_ps, v_pe, v_up_cur, v_up_prev, v_up_rel,
                round(greatest(0, least(v_up_rel * 100, 100)), 2),
                round(greatest(0, least(v_cvr_rel * 100, 100)), 2),
                round(greatest(0, 1 - (coalesce(v_refund_rel, 0) + 0.05) * 5) * 100, 2),
                round(v_score, 2), v_level, round(v_avail, 2),
                '同域peer(' || p_domain_key || ')', v_peer_count, round(coalesce(v_peer_p50, 0), 4), round(coalesce(v_peer_p75, 0), 4),
                true, NULLIF(v_flags, ''), 'OP|' || p_domain_key || '|' || coalesce(r_ent.entity_name, ''),
                v_status, '机会评分=' || round(v_score, 0) || '（机会质量排序分，非未来成功概率）', now())
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;

    DROP TABLE IF EXISTS snap_rows;
    RETURN (SELECT count(*)::int FROM mart.opportunity_event
            WHERE current_start_date = p_start_date AND current_end_date = p_end_date
              AND domain_key = p_domain_key AND platform_code = p_platform_code);
END;
$function$;

COMMENT ON FUNCTION mart.detect_growth_opportunities(text,date,date,text,text) IS
'V1.1 机会检测：同域 peer 分池 + 7 维评分（缺失重归一）+ O01-O08 类型判定 + 幂等。';

-- ----------------------------------------------------------------------------
-- 查询函数
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.get_growth_opportunities(text,date,date,text,text,text);
CREATE FUNCTION mart.get_growth_opportunities(
    p_platform_code text DEFAULT 'douyin',
    p_start_date    date DEFAULT NULL,
    p_end_date      date DEFAULT NULL,
    p_domain_key    text DEFAULT NULL,
    p_opportunity_code text DEFAULT NULL,
    p_min_level     text DEFAULT NULL
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
      AND (p_start_date IS NULL OR e.current_start_date = p_start_date)
      AND (p_end_date IS NULL OR e.current_end_date = p_end_date)
      AND (p_domain_key IS NULL OR e.domain_key = p_domain_key)
      AND (p_opportunity_code IS NULL OR e.opportunity_code = p_opportunity_code)
      AND (p_min_level IS NULL OR
           (e.opportunity_level='LOW' AND p_min_level='LOW') OR
           (e.opportunity_level IN ('MEDIUM','HIGH','STRONG') AND p_min_level IN ('MEDIUM','HIGH','STRONG')) OR
           (e.opportunity_level IN ('HIGH','STRONG') AND p_min_level='HIGH') OR
           (e.opportunity_level='STRONG' AND p_min_level='STRONG'))
    ORDER BY e.opportunity_score DESC;
$f$;

DROP FUNCTION IF EXISTS mart.get_opportunity_summary(text,date,date,text);
CREATE FUNCTION mart.get_opportunity_summary(
    p_platform_code text DEFAULT 'douyin',
    p_start_date    date DEFAULT NULL,
    p_end_date      date DEFAULT NULL,
    p_status        text DEFAULT 'QUALIFIED'
) RETURNS TABLE (
    domain_key text, opportunity_code text, opportunity_name_cn text,
    event_count bigint, max_score numeric, avg_score numeric,
    level_distribution text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $f$
    SELECT e.domain_key, e.opportunity_code, t.opportunity_name_cn,
           count(*)::bigint, max(e.opportunity_score), avg(e.opportunity_score),
           string_agg(DISTINCT e.opportunity_level, '/' ORDER BY e.opportunity_level)
    FROM mart.opportunity_event e
    JOIN mart.opportunity_type t ON t.opportunity_code = e.opportunity_code
    WHERE e.platform_code = p_platform_code
      AND (p_start_date IS NULL OR e.current_start_date = p_start_date)
      AND (p_end_date IS NULL OR e.current_end_date = p_end_date)
      AND (p_status IS NULL OR e.status = p_status)
    GROUP BY e.domain_key, e.opportunity_code, t.opportunity_name_cn
    ORDER BY count(*) DESC;
$f$;
