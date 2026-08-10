-- ============================================================================
-- V1.1 阶段5｜经营优先级与每日行动清单（多店兼容修订版）
-- 02_generate_daily.sql（每日行动生成器 + 查询函数）
-- ============================================================================
-- 只消费 Stage2 anomaly_event / Stage4 opportunity_event。
-- risk/opportunity 独立优先级；chain 去重（同链仅 1 主卡）；冷却=更新原卡；跨域上限。
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 每日行动生成器（后台可调用；幂等 + 冷却）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.generate_daily_action_items(text,date,date);
CREATE FUNCTION mart.generate_daily_action_items(
    p_platform_code text,
    p_start_date    date,
    p_end_date      date
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $function$
DECLARE
    v_ins int := 0; v_upd int := 0;
BEGIN
    -- ========== 0. 冷却：同 dedupe 键的 OPEN 卡更新原卡（不重复生成） ==========
    UPDATE mart.daily_action_item a SET
        occurrence_count = a.occurrence_count + 1,
        last_seen_date = p_end_date,
        updated_at = now()
    FROM mart.anomaly_event e
    JOIN mart.anomaly_rule r ON r.rule_code = e.anomaly_type
    WHERE a.dedupe_group_key = e.diagnostic_chain_key || '|RISK|' || e.entity_id
      AND e.platform_code = p_platform_code
      AND e.current_start_date = p_start_date AND e.current_end_date = p_end_date
      AND e.status = 'OPEN'
      AND a.status IN ('OPEN','WATCHING');

    UPDATE mart.daily_action_item a SET
        occurrence_count = a.occurrence_count + 1,
        last_seen_date = p_end_date,
        updated_at = now()
    FROM mart.opportunity_event e
    WHERE a.dedupe_group_key = e.diagnostic_chain_id || '|OPP|' || e.entity_id
      AND e.platform_code = p_platform_code
      AND e.current_start_date = p_start_date AND e.current_end_date = p_end_date
      AND e.status = 'QUALIFIED'
      AND a.status IN ('OPEN','WATCHING');

    UPDATE mart.daily_action_item a SET
        occurrence_count = a.occurrence_count + 1,
        last_seen_date = p_end_date,
        updated_at = now()
    FROM mart.opportunity_event e
    WHERE a.dedupe_group_key = e.diagnostic_chain_id || '|WATCH|' || e.entity_id || '|' || e.status
      AND e.platform_code = p_platform_code
      AND e.current_start_date = p_start_date AND e.current_end_date = p_end_date
      AND e.status IN ('LOW_BASE','NEW_BASE_SIGNAL','INSUFFICIENT_PEERS','INSUFFICIENT_EVIDENCE','COVERAGE_INCOMPLETE','MAPPING_INCOMPLETE')
      AND a.status IN ('OPEN','WATCHING');

    -- ========== 1. RISK：从 OPEN anomaly_event 生成 ==========
    INSERT INTO mart.daily_action_item
        (platform_code, shop_name, entity_level, domain_key, entity_id, entity_name, scope_key,
         master_product_id, product_line_id, item_type, source_anomaly_code,
         risk_priority_score, risk_level, action_category,
         current_start_date, current_end_date, business_impact, impact_source,
         coverage_complete, mapping_complete, diagnostic_chain_id, action_group_key, dedupe_group_key,
         status, first_seen_date, last_seen_date, occurrence_count, notes, created_at, updated_at)
    SELECT
        e.platform_code, e.shop_name, e.domain_key, e.domain_key, e.entity_id, e.entity_name, e.scope_key,
        CASE WHEN e.domain_key='master_product' THEN e.entity_id END AS master_product_id,
        CASE WHEN e.domain_key='product_line' THEN e.entity_id END AS product_line_id,
        'RISK', e.anomaly_type,
        -- risk_priority_score：severity30 + impact25 + persistence15 + strategic10 + confidence10 + evidence10
        round(
            e.severity_score * 0.30
            + least(e.materiality / 100000, 1) * 25
            + least(e.consecutive_day_count, 10) * 1.5
            + (SELECT coalesce(w.strategic_weight, 1.0) * 10 FROM mart.priority_entity_weight w WHERE w.entity_level = e.domain_key)
            + CASE WHEN e.coverage_complete THEN 10 ELSE 0 END
            + 10,
        2) AS risk_score,
        CASE WHEN (e.severity_score * 0.30 + least(e.materiality / 100000, 1) * 25
                   + least(e.consecutive_day_count, 10) * 1.5
                   + (SELECT coalesce(w.strategic_weight, 1.0) * 10 FROM mart.priority_entity_weight w WHERE w.entity_level = e.domain_key)
                   + CASE WHEN e.coverage_complete THEN 10 ELSE 0 END + 10) >= 90 THEN 'P1_URGENT'
             WHEN (e.severity_score * 0.30 + least(e.materiality / 100000, 1) * 25
                   + least(e.consecutive_day_count, 10) * 1.5
                   + (SELECT coalesce(w.strategic_weight, 1.0) * 10 FROM mart.priority_entity_weight w WHERE w.entity_level = e.domain_key)
                   + CASE WHEN e.coverage_complete THEN 10 ELSE 0 END + 10) >= 75 THEN 'P2_HIGH'
             WHEN (e.severity_score * 0.30 + least(e.materiality / 100000, 1) * 25
                   + least(e.consecutive_day_count, 10) * 1.5
                   + (SELECT coalesce(w.strategic_weight, 1.0) * 10 FROM mart.priority_entity_weight w WHERE w.entity_level = e.domain_key)
                   + CASE WHEN e.coverage_complete THEN 10 ELSE 0 END + 10) >= 60 THEN 'P3_MEDIUM'
             ELSE 'P4_LOW' END,
        CASE e.anomaly_type
            WHEN 'A01_SALES_DROP' THEN 'CHECK_CONVERSION'
            WHEN 'A02_SALES_SPIKE' THEN 'CHECK_TRAFFIC'
            WHEN 'A03_TRAFFIC_DROP' THEN 'CHECK_TRAFFIC'
            WHEN 'A04_CLICK_RATE_DROP' THEN 'CHECK_CLICK'
            WHEN 'A05_CONVERSION_DROP' THEN 'CHECK_CONVERSION'
            WHEN 'A06_REFUND_DETERIORATION' THEN 'CHECK_REFUND'
            WHEN 'A07_AD_EFFICIENCY_DETERIORATION' THEN 'CHECK_AD_EFFICIENCY'
            WHEN 'A08_CONTRIBUTION_DROP' THEN 'CHECK_CONTRIBUTION'
            ELSE 'CHECK_TRAFFIC' END,
        e.current_start_date, e.current_end_date,
        e.materiality, 'stage2_materiality',
        e.coverage_complete, e.mapping_complete,
        e.diagnostic_chain_key, e.diagnostic_chain_key || '|RISK', e.diagnostic_chain_key || '|RISK|' || e.entity_id,
        'OPEN', e.current_start_date, e.current_end_date, 1,
        '排查方向（非已证原因）：' || r.rule_name_cn, now(), now()
    FROM mart.anomaly_event e
    JOIN mart.anomaly_rule r ON r.rule_code = e.anomaly_type
    WHERE e.platform_code = p_platform_code
      AND e.current_start_date = p_start_date AND e.current_end_date = p_end_date
      AND e.status = 'OPEN'
    ON CONFLICT DO NOTHING;

    -- ========== 2. OPPORTUNITY：从 QUALIFIED opportunity_event 生成 ==========
    INSERT INTO mart.daily_action_item
        (platform_code, shop_name, entity_level, domain_key, entity_id, entity_name, scope_key,
         master_product_id, product_line_id, item_type, source_opportunity_code,
         opportunity_priority_score, opportunity_level, action_category,
         current_start_date, current_end_date, business_impact, impact_source,
         coverage_complete, mapping_complete, diagnostic_chain_id, action_group_key, dedupe_group_key,
         status, first_seen_date, last_seen_date, occurrence_count, notes, created_at, updated_at)
    SELECT
        e.platform_code, e.shop_name, e.domain_key, e.domain_key, e.entity_id, e.entity_name, e.scope_key,
        CASE WHEN e.domain_key='master_product' THEN e.entity_id END,
        CASE WHEN e.domain_key='product_line' THEN e.entity_id END,
        'OPPORTUNITY', e.opportunity_code,
        -- opportunity_priority_score：Stage4 40 + volume 20 + persistence 15 + strategic 10 + risk_safety 10 + evidence 5
        round(
            e.opportunity_score * 0.40
            + least(e.current_value / 100000, 1) * 20
            + (CASE WHEN e.relative_change > 0 THEN 15 ELSE 0 END)
            + (SELECT coalesce(w.strategic_weight, 1.0) * 10 FROM mart.priority_entity_weight w WHERE w.entity_level = e.domain_key)
            + CASE WHEN e.risk_flags IS NULL THEN 10 ELSE 2 END
            + 5,
        2) AS opp_score,
        CASE WHEN (e.opportunity_score * 0.40 + least(e.current_value / 100000, 1) * 20
                   + (CASE WHEN e.relative_change > 0 THEN 15 ELSE 0 END)
                   + (SELECT coalesce(w.strategic_weight, 1.0) * 10 FROM mart.priority_entity_weight w WHERE w.entity_level = e.domain_key)
                   + CASE WHEN e.risk_flags IS NULL THEN 10 ELSE 2 END + 5) >= 85 THEN 'O1_STRONG'
             WHEN (e.opportunity_score * 0.40 + least(e.current_value / 100000, 1) * 20
                   + (CASE WHEN e.relative_change > 0 THEN 15 ELSE 0 END)
                   + (SELECT coalesce(w.strategic_weight, 1.0) * 10 FROM mart.priority_entity_weight w WHERE w.entity_level = e.domain_key)
                   + CASE WHEN e.risk_flags IS NULL THEN 10 ELSE 2 END + 5) >= 70 THEN 'O2_HIGH'
             WHEN (e.opportunity_score * 0.40 + least(e.current_value / 100000, 1) * 20
                   + (CASE WHEN e.relative_change > 0 THEN 15 ELSE 0 END)
                   + (SELECT coalesce(w.strategic_weight, 1.0) * 10 FROM mart.priority_entity_weight w WHERE w.entity_level = e.domain_key)
                   + CASE WHEN e.risk_flags IS NULL THEN 10 ELSE 2 END + 5) >= 55 THEN 'O3_MEDIUM'
             ELSE 'O4_WATCH' END,
        CASE WHEN e.domain_key='product_line' THEN 'WATCH_PRODUCT_LINE_GROWTH'
             WHEN e.domain_key='category' THEN 'WATCH_CATEGORY_GROWTH'
             WHEN e.opportunity_code='O02_CONVERSION_IMPROVEMENT' THEN 'WATCH_CONVERSION_IMPROVEMENT'
             WHEN e.opportunity_code='O03_TRAFFIC_SCALE_OPPORTUNITY' THEN 'WATCH_TRAFFIC_SCALE'
             WHEN e.opportunity_code='O04_HIGH_EFFICIENCY_AD_OPPORTUNITY' THEN 'WATCH_AD_OPPORTUNITY'
             WHEN e.opportunity_code='O07_CHANNEL_EXPANSION_OPPORTUNITY' THEN 'WATCH_CHANNEL_GROWTH'
             ELSE 'WATCH_GROWTH' END,
        e.current_start_date, e.current_end_date,
        e.current_value, 'stage4_current_value',
        e.coverage_complete, e.mapping_complete,
        e.diagnostic_chain_id, e.diagnostic_chain_id || '|OPP', e.diagnostic_chain_id || '|OPP|' || e.entity_id,
        'OPEN', e.current_start_date, e.current_end_date, 1,
        '机会质量排序分（非未来成功概率）' || CASE WHEN e.risk_flags IS NOT NULL THEN '；并存风险:' || e.risk_flags ELSE '' END,
        now(), now()
    FROM mart.opportunity_event e
    WHERE e.platform_code = p_platform_code
      AND e.current_start_date = p_start_date AND e.current_end_date = p_end_date
      AND e.status = 'QUALIFIED'
    ON CONFLICT DO NOTHING;

    -- ========== 3. WATCH：coverage/mapping/证据不足状态事件 ==========
    INSERT INTO mart.daily_action_item
        (platform_code, shop_name, entity_level, domain_key, entity_id, entity_name, scope_key,
         item_type, action_category, current_start_date, current_end_date,
         diagnostic_chain_id, dedupe_group_key, status, first_seen_date, last_seen_date, occurrence_count, notes, created_at, updated_at)
    SELECT e.platform_code, e.shop_name, e.domain_key, e.domain_key, e.entity_id, e.entity_name, e.scope_key,
           'WATCH', 'WATCH_GROWTH', e.current_start_date, e.current_end_date,
           e.diagnostic_chain_id, e.diagnostic_chain_id || '|WATCH|' || e.entity_id || '|' || e.status,
           'WATCHING', e.current_start_date, e.current_end_date, 1,
           '观察：' || e.status || '（' || e.notes || '）', now(), now()
    FROM mart.opportunity_event e
    WHERE e.platform_code = p_platform_code
      AND e.current_start_date = p_start_date AND e.current_end_date = p_end_date
      AND e.status IN ('LOW_BASE','NEW_BASE_SIGNAL','INSUFFICIENT_PEERS','INSUFFICIENT_EVIDENCE','COVERAGE_INCOMPLETE','MAPPING_INCOMPLETE')
    ON CONFLICT DO NOTHING;

    RETURN (SELECT count(*)::int FROM mart.daily_action_item
            WHERE current_start_date = p_start_date AND current_end_date = p_end_date AND platform_code = p_platform_code);
END;
$function$;

COMMENT ON FUNCTION mart.generate_daily_action_items(text,date,date) IS
'V1.1 每日行动生成器（后台）：消费异常/机会/观察事件 → RISK/OPPORTUNITY/WATCH 三类行动项；冷却=更新原卡；幂等。';

-- ----------------------------------------------------------------------------
-- 查询函数（agent_readonly 可执行）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.get_daily_risk_priorities(text,date,date,integer);
CREATE FUNCTION mart.get_daily_risk_priorities(
    p_platform_code text DEFAULT 'douyin',
    p_start_date    date DEFAULT NULL,
    p_end_date      date DEFAULT NULL,
    p_limit         integer DEFAULT 5
) RETURNS TABLE (
    action_item_id bigint, shop_name text, entity_level text, entity_id text, entity_name text,
    source_anomaly_code text, risk_priority_score numeric, risk_level text,
    action_category text, business_impact numeric, occurrence_count integer,
    diagnostic_chain_id text, coverage_complete boolean, status text, notes text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $f$
    SELECT t.action_item_id, t.shop_name, t.entity_level, t.entity_id, t.entity_name,
           t.source_anomaly_code, t.risk_priority_score, t.risk_level,
           t.action_category, t.business_impact, t.occurrence_count,
           t.diagnostic_chain_id, t.coverage_complete, t.status, t.notes
    FROM (
        SELECT DISTINCT ON (a.entity_id, a.scope_key)
               a.action_item_id, a.shop_name, a.entity_level, a.entity_id, a.entity_name,
               a.source_anomaly_code, a.risk_priority_score, a.risk_level,
               a.action_category, a.business_impact, a.occurrence_count,
               a.diagnostic_chain_id, a.coverage_complete, a.status, a.notes
        FROM mart.daily_action_item a
        WHERE a.platform_code = p_platform_code AND a.item_type = 'RISK'
          AND (p_start_date IS NULL OR a.current_start_date = p_start_date)
          AND (p_end_date IS NULL OR a.current_end_date = p_end_date)
          AND a.status IN ('OPEN','WATCHING')
        ORDER BY a.entity_id, a.scope_key, a.risk_priority_score DESC NULLS LAST
    ) t
    ORDER BY t.risk_priority_score DESC NULLS LAST
    LIMIT p_limit;
$f$;

DROP FUNCTION IF EXISTS mart.get_daily_opportunity_priorities(text,date,date,integer);
CREATE FUNCTION mart.get_daily_opportunity_priorities(
    p_platform_code text DEFAULT 'douyin',
    p_start_date    date DEFAULT NULL,
    p_end_date      date DEFAULT NULL,
    p_limit         integer DEFAULT 5
) RETURNS TABLE (
    action_item_id bigint, shop_name text, entity_level text, entity_id text, entity_name text,
    source_opportunity_code text, opportunity_priority_score numeric, opportunity_level text,
    action_category text, business_impact numeric, occurrence_count integer,
    diagnostic_chain_id text, coverage_complete boolean, status text, notes text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $f$
    SELECT t.action_item_id, t.shop_name, t.entity_level, t.entity_id, t.entity_name,
           t.source_opportunity_code, t.opportunity_priority_score, t.opportunity_level,
           t.action_category, t.business_impact, t.occurrence_count,
           t.diagnostic_chain_id, t.coverage_complete, t.status, t.notes
    FROM (
        SELECT DISTINCT ON (a.entity_id, a.scope_key)
               a.action_item_id, a.shop_name, a.entity_level, a.entity_id, a.entity_name,
               a.source_opportunity_code, a.opportunity_priority_score, a.opportunity_level,
               a.action_category, a.business_impact, a.occurrence_count,
               a.diagnostic_chain_id, a.coverage_complete, a.status, a.notes
        FROM mart.daily_action_item a
        WHERE a.platform_code = p_platform_code AND a.item_type = 'OPPORTUNITY'
          AND (p_start_date IS NULL OR a.current_start_date = p_start_date)
          AND (p_end_date IS NULL OR a.current_end_date = p_end_date)
          AND a.status IN ('OPEN','WATCHING')
        ORDER BY a.entity_id, a.scope_key, a.opportunity_priority_score DESC NULLS LAST
    ) t
    ORDER BY t.opportunity_priority_score DESC NULLS LAST
    LIMIT p_limit;
$f$;

DROP FUNCTION IF EXISTS mart.get_daily_action_list(text,date,date,text,integer);
CREATE FUNCTION mart.get_daily_action_list(
    p_platform_code text DEFAULT 'douyin',
    p_start_date    date DEFAULT NULL,
    p_end_date      date DEFAULT NULL,
    p_item_type     text DEFAULT NULL,
    p_limit         integer DEFAULT 20
) RETURNS TABLE (
    action_item_id bigint, shop_name text, entity_level text, entity_name text, scope_key text,
    item_type text, source_anomaly_code text, source_opportunity_code text,
    risk_priority_score numeric, opportunity_priority_score numeric,
    risk_level text, opportunity_level text, action_category text,
    business_impact numeric, occurrence_count integer,
    diagnostic_chain_id text, status text, notes text, last_seen_date date
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $f$
    SELECT a.action_item_id, a.shop_name, a.entity_level, a.entity_name, a.scope_key,
           a.item_type, a.source_anomaly_code, a.source_opportunity_code,
           a.risk_priority_score, a.opportunity_priority_score,
           a.risk_level, a.opportunity_level, a.action_category,
           a.business_impact, a.occurrence_count,
           a.diagnostic_chain_id, a.status, a.notes, a.last_seen_date
    FROM mart.daily_action_item a
    WHERE a.platform_code = p_platform_code
      AND (p_start_date IS NULL OR a.current_start_date = p_start_date)
      AND (p_end_date IS NULL OR a.current_end_date = p_end_date)
      AND (p_item_type IS NULL OR a.item_type = p_item_type)
    ORDER BY coalesce(a.risk_priority_score, a.opportunity_priority_score) DESC NULLS LAST
    LIMIT p_limit;
$f$;

DROP FUNCTION IF EXISTS mart.get_daily_business_brief(text,date,date);
CREATE FUNCTION mart.get_daily_business_brief(
    p_platform_code text DEFAULT 'douyin',
    p_start_date    date DEFAULT NULL,
    p_end_date      date DEFAULT NULL
) RETURNS TABLE (
    brief_type text, item_type text, entity_level text, entity_name text,
    priority_score numeric, level text, action_category text, business_impact numeric, notes text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $f$
    (SELECT 'TOP5_RISK'::text AS brief_type, a.item_type, a.entity_level, a.entity_name,
            a.risk_priority_score, a.risk_level, a.action_category, a.business_impact, a.notes
     FROM mart.daily_action_item a
     WHERE a.platform_code = p_platform_code AND a.item_type='RISK'
       AND (p_start_date IS NULL OR a.current_start_date = p_start_date)
       AND (p_end_date IS NULL OR a.current_end_date = p_end_date) AND a.status='OPEN'
     ORDER BY a.risk_priority_score DESC NULLS LAST LIMIT 5)
    UNION ALL
    (SELECT 'TOP5_OPPORTUNITY', a.item_type, a.entity_level, a.entity_name,
            a.opportunity_priority_score, a.opportunity_level, a.action_category, a.business_impact, a.notes
     FROM mart.daily_action_item a
     WHERE a.platform_code = p_platform_code AND a.item_type='OPPORTUNITY'
       AND (p_start_date IS NULL OR a.current_start_date = p_start_date)
       AND (p_end_date IS NULL OR a.current_end_date = p_end_date) AND a.status='OPEN'
     ORDER BY a.opportunity_priority_score DESC NULLS LAST LIMIT 5)
    UNION ALL
    (SELECT 'TOP5_WATCH', a.item_type, a.entity_level, a.entity_name,
            NULL::numeric, NULL::text, a.action_category, a.business_impact, a.notes
     FROM mart.daily_action_item a
     WHERE a.platform_code = p_platform_code AND a.item_type='WATCH'
       AND (p_start_date IS NULL OR a.current_start_date = p_start_date)
       AND (p_end_date IS NULL OR a.current_end_date = p_end_date)
     ORDER BY a.last_seen_date DESC LIMIT 5);
$f$;
