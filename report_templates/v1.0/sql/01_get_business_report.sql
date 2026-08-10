-- ============================================================================
-- 抖音日报/周报数据模板 V1.0 报表函数（无利润计算版本）
-- ----------------------------------------------------------------------------
-- 结构：三板块 × 六行
--   板块一 抖音整体（两店合计）
--   板块二 抖音弹动官方旗舰店（shop_id=1）
--   板块三 抖音弹动个人护理旗舰店（shop_id=2）
--   每板块六行：整体(店铺全名) / 自营直播 / 自营商品 / 达人直播 / 达人短视频 / 橱窗
-- ----------------------------------------------------------------------------
-- 指标口径（模板 V1.0 第四、五节）：
--   成交金额     = SUM(user_pay_amount)
--   成交退款金额 = SUM(refund_amount_pay_time)   [成交退款金额(支付时间)]
--   结算金额     = SUM(settlement_amount)
--   退款率       = SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount),0)  （小数，展示×100）
--   投放消耗     = SUM(ad_spend_shop_promoted)   [投放消耗(店铺被投)]
--   投放费比     = SUM(ad_spend_shop_bound) / NULLIF(SUM(settlement_amount),0)   （小数，展示×100，剔除退款、店铺绑定）
-- 经营类型归并（模板 V1.0 第四节）：
--   自营直播   = sale_scope='自营' AND carrier_type='直播'
--   自营商品   = sale_scope='自营' AND carrier_type IN ('短视频','商品卡','其他','图文')
--   达人直播   = sale_scope='合作' AND carrier_type='直播'
--   达人短视频 = sale_scope='合作' AND carrier_type IN ('短视频','图文')
--   橱窗       = sale_scope='合作' AND carrier_type IN ('商品卡','其他')
--   整体       = sale_scope='全部' AND carrier_type='全部'
-- ----------------------------------------------------------------------------
-- 关键防重口径：仅取 ad_period='不限'（平台汇总行 = 全域+乘方 + 标准+品牌 + 非投放 之和，
--   已验证 2026-06-01 全店行 用户支付金额 差异=0），避免把汇总行与时段行重复累加。
-- 安全：SECURITY DEFINER + 固定 search_path，与 mart 既有函数一致。
-- ============================================================================

DROP FUNCTION IF EXISTS mart.get_business_report(date,date);

CREATE OR REPLACE FUNCTION mart.get_business_report(
    p_start_date date,
    p_end_date date
) RETURNS TABLE (
    section           text,      -- 板块：抖音整体 / 抖音弹动官方旗舰店 / 抖音弹动个人护理旗舰店
    business_type     text,      -- 经营类型：整体行=店铺全名；其余=自营直播/自营商品/达人直播/达人短视频/橱窗
    user_pay_amount   numeric,   -- 成交金额
    refund_amount     numeric,   -- 成交退款金额
    settlement_amount numeric,   -- 结算金额
    refund_rate       numeric,   -- 退款率（小数，如 0.1656；展示 ×100%）
    ad_spend          numeric,   -- 投放消耗（店铺被投）
    ad_fee_rate       numeric,   -- 投放费比（剔除退款、店铺绑定；小数）
    ad_bound          numeric    -- 投放消耗（店铺绑定，费比分子；供周报跨期聚合用）
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $function$
DECLARE
    v_min_date date;
    v_max_date date;
BEGIN
    -- ---------- 周期校验 ----------
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION 'p_start_date / p_end_date 不能为空';
    END IF;
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION 'p_start_date(%) 不能晚于 p_end_date(%)', p_start_date, p_end_date;
    END IF;
    SELECT min(biz_date), max(biz_date) INTO v_min_date, v_max_date FROM core.douyin_deal_daily;
    IF p_start_date < v_min_date OR p_end_date > v_max_date THEN
        RAISE EXCEPTION '区间 % ~ % 超出数据覆盖范围(% ~ %)', p_start_date, p_end_date, v_min_date, v_max_date;
    END IF;

    RETURN QUERY
    WITH filtered AS (
        SELECT d.shop_id,
               d.biz_date,
               CASE
                   WHEN d.sale_scope = '全部' AND d.carrier_type = '全部'
                       THEN '整体'
                   WHEN d.sale_scope = '自营' AND d.carrier_type = '直播'
                       THEN '自营直播'
                   WHEN d.sale_scope = '自营' AND d.carrier_type IN ('短视频','商品卡','其他','图文')
                       THEN '自营商品'
                   WHEN d.sale_scope = '合作' AND d.carrier_type = '直播'
                       THEN '达人直播'
                   WHEN d.sale_scope = '合作' AND d.carrier_type IN ('短视频','图文')
                       THEN '达人短视频'
                   WHEN d.sale_scope = '合作' AND d.carrier_type IN ('商品卡','其他')
                       THEN '橱窗'
                   ELSE NULL
               END AS biz_type,
               d.user_pay_amount       AS f_user_pay,
               d.refund_amount_pay_time AS f_refund,
               d.settlement_amount      AS f_settlement,
               d.ad_spend_shop_promoted AS f_ad_spend,
               d.ad_spend_shop_bound    AS f_ad_bound
        FROM core.douyin_deal_daily d
        WHERE d.biz_date BETWEEN p_start_date AND p_end_date
          AND d.ad_period = '不限'
          AND (   (d.sale_scope = '全部' AND d.carrier_type = '全部')     -- 整体行
               OR (d.sale_scope <> '全部' AND d.carrier_type <> '全部'))  -- 经营类型明细行
    ),
    agg AS (
        -- 抖音整体：跨两店合计
        SELECT NULL::bigint AS shop_id,
               biz_type,
               round(sum(f_user_pay), 2)                                   AS user_pay_amount,
               round(sum(f_refund), 2)                                     AS refund_amount,
               round(sum(f_settlement), 2)                                 AS settlement_amount,
               round(sum(f_refund) / NULLIF(sum(f_user_pay), 0), 10)       AS refund_rate,
               round(sum(f_ad_spend), 2)                                   AS ad_spend,
               round(sum(f_ad_bound) / NULLIF(sum(f_settlement), 0), 10)   AS ad_fee_rate,
               round(sum(f_ad_bound), 2)                                   AS ad_bound
        FROM filtered
        WHERE biz_type IS NOT NULL
        GROUP BY biz_type
        UNION ALL
        -- 单店板块
        SELECT shop_id,
               biz_type,
               round(sum(f_user_pay), 2),
               round(sum(f_refund), 2),
               round(sum(f_settlement), 2),
               round(sum(f_refund) / NULLIF(sum(f_user_pay), 0), 10),
               round(sum(f_ad_spend), 2),
               round(sum(f_ad_bound) / NULLIF(sum(f_settlement), 0), 10),
               round(sum(f_ad_bound), 2)
        FROM filtered
        WHERE biz_type IS NOT NULL
          AND shop_id IS NOT NULL
        GROUP BY shop_id, biz_type
    ),
    template AS (
        SELECT * FROM (VALUES
            -- 板块一 抖音整体（shop_id=NULL = 跨店合计）
            (1, 1, '抖音整体',                '抖音整体',                NULL::bigint, '整体'),
            (1, 2, '抖音整体',                '自营直播',                NULL,         '自营直播'),
            (1, 3, '抖音整体',                '自营商品',                NULL,         '自营商品'),
            (1, 4, '抖音整体',                '达人直播',                NULL,         '达人直播'),
            (1, 5, '抖音整体',                '达人短视频',              NULL,         '达人短视频'),
            (1, 6, '抖音整体',                '橱窗',                    NULL,         '橱窗'),
            -- 板块二 抖音弹动官方旗舰店（shop_id=1）
            (2, 1, '抖音弹动官方旗舰店',     '抖音弹动官方旗舰店',      1::bigint,    '整体'),
            (2, 2, '抖音弹动官方旗舰店',     '自营直播',                1,            '自营直播'),
            (2, 3, '抖音弹动官方旗舰店',     '自营商品',                1,            '自营商品'),
            (2, 4, '抖音弹动官方旗舰店',     '达人直播',                1,            '达人直播'),
            (2, 5, '抖音弹动官方旗舰店',     '达人短视频',              1,            '达人短视频'),
            (2, 6, '抖音弹动官方旗舰店',     '橱窗',                    1,            '橱窗'),
            -- 板块三 抖音弹动个人护理旗舰店（shop_id=2）
            (3, 1, '抖音弹动个人护理旗舰店', '抖音弹动个人护理旗舰店',  2::bigint,    '整体'),
            (3, 2, '抖音弹动个人护理旗舰店', '自营直播',                2,            '自营直播'),
            (3, 3, '抖音弹动个人护理旗舰店', '自营商品',                2,            '自营商品'),
            (3, 4, '抖音弹动个人护理旗舰店', '达人直播',                2,            '达人直播'),
            (3, 5, '抖音弹动个人护理旗舰店', '达人短视频',              2,            '达人短视频'),
            (3, 6, '抖音弹动个人护理旗舰店', '橱窗',                    2,            '橱窗')
        ) AS t(section_seq, row_seq, section, business_type, filter_shop_id, biz_type)
    )
    SELECT t.section,
           t.business_type,
           COALESCE(a.user_pay_amount, 0),
           COALESCE(a.refund_amount, 0),
           COALESCE(a.settlement_amount, 0),
           a.refund_rate,
           COALESCE(a.ad_spend, 0),
           a.ad_fee_rate,
           COALESCE(a.ad_bound, 0)
    FROM template t
    LEFT JOIN agg a
           ON a.biz_type = t.biz_type
          AND a.shop_id IS NOT DISTINCT FROM t.filter_shop_id
    ORDER BY t.section_seq, t.row_seq;
END;
$function$;

-- 与既有 mart 函数一致：PUBLIC 可执行（agent_readonly 依赖此路径），core 仍不可直读
GRANT EXECUTE ON FUNCTION mart.get_business_report(date,date) TO PUBLIC;
GRANT EXECUTE ON FUNCTION mart.get_business_report(date,date) TO agent_readonly;

COMMENT ON FUNCTION mart.get_business_report(date,date) IS
'抖音日报/周报数据模板 V1.0 报表：三板块(抖音整体/抖音弹动官方旗舰店/抖音弹动个人护理旗舰店)×六行(整体/自营直播/自营商品/达人直播/达人短视频/橱窗)。
指标：成交金额=SUM(user_pay_amount)、成交退款金额=SUM(refund_amount_pay_time)、结算金额=SUM(settlement_amount)、
退款率=退款金额/成交金额、投放消耗=SUM(ad_spend_shop_promoted)、投放费比=SUM(ad_spend_shop_bound)/SUM(settlement_amount)。
防重口径：仅取 ad_period=不限(平台汇总行)。比率返回小数。无利润计算。';
