-- ============================================================
-- mart V1.0 阶段2 | 业务域 Period Function (Part2)
-- category / product / price_band / audience
-- ============================================================

-- ############################################################
-- 5. get_category_period_summary: 类目拆分
-- 规则: 必须使用 category_level/is_total_row; 不同层级禁止混SUM;
--       p_category_level 指定1/2/3时只查该层级
-- ############################################################
CREATE OR REPLACE FUNCTION mart.get_category_period_summary(
    p_shop_name      text DEFAULT NULL,
    p_start_date     date DEFAULT NULL,
    p_end_date       date DEFAULT NULL,
    p_category_level int DEFAULT NULL,
    p_category_l1    text DEFAULT NULL,
    p_category_l2    text DEFAULT NULL,
    p_category_l3    text DEFAULT NULL,
    p_category_l4    text DEFAULT NULL
) RETURNS TABLE(
    shop_name character varying,
    start_date date,
    end_date date,
    day_count integer,
    category_level int,
    is_total_row boolean,
    category_l1 character varying,
    category_l2 character varying,
    category_l3 character varying,
    category_l4 character varying,
    -- SUM
    user_pay_amount numeric,
    refund_amount_pay_time numeric,
    -- ratio (V1.4)
    refund_rate_pay_time numeric,           -- 89
    -- source_only (缺基础字段)
    avg_transaction_order_amount numeric,   -- 87
    click_to_transaction_rate_events numeric, -- 88
    source_only_note text
) AS $$
DECLARE v_single_day boolean;
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION '参数错误: p_start_date 和 p_end_date 不能为空';
    END IF;
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION '参数错误: p_start_date(%) 不能晚于 p_end_date(%)', p_start_date, p_end_date;
    END IF;
    IF p_category_level IS NOT NULL AND p_category_level NOT IN (1,2,3,4) THEN
        RAISE EXCEPTION '参数错误: p_category_level 仅支持 1/2/3/4, 收到 %', p_category_level;
    END IF;
    v_single_day := (p_start_date = p_end_date);

    RETURN QUERY
    SELECT
        s.shop_name, p_start_date, p_end_date,
        (p_end_date - p_start_date + 1)::int,
        c.category_level::int, c.is_total_row,
        c.category_l1::varchar, c.category_l2::varchar, c.category_l3::varchar, c.category_l4::varchar,
        SUM(c.user_pay_amount),
        SUM(c.refund_amount_pay_time),
        SUM(c.refund_amount_pay_time) / NULLIF(SUM(c.user_pay_amount), 0),
        CASE WHEN v_single_day THEN MAX(c.avg_transaction_order_amount) ELSE NULL END,
        CASE WHEN v_single_day THEN MAX(c.click_to_transaction_rate_events) ELSE NULL END,
        CASE WHEN v_single_day THEN '单日: source_only返回当天源值'
             ELSE '多日: 成交笔单价/点击成交转化率(缺基础字段)不可跨期重算, 返回NULL' END
    FROM mart.category_daily c
    JOIN meta.shop s ON c.shop_name = s.shop_name
    WHERE (p_shop_name IS NULL OR c.shop_name = p_shop_name)
      AND (p_category_level IS NULL OR c.category_level = p_category_level)
      AND (p_category_l1 IS NULL OR c.category_l1 = p_category_l1)
      AND (p_category_l2 IS NULL OR c.category_l2 = p_category_l2)
      AND (p_category_l3 IS NULL OR c.category_l3 = p_category_l3)
      AND (p_category_l4 IS NULL OR c.category_l4 = p_category_l4)
      AND c.biz_date BETWEEN p_start_date AND p_end_date
    GROUP BY s.shop_name, c.category_level, c.is_total_row,
             c.category_l1, c.category_l2, c.category_l3, c.category_l4;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mart.get_category_period_summary(text,date,date,int,text,text,text,text) IS
'类目动态区间汇总。使用category_level/is_total_row治理; 不同层级禁止混SUM; 推荐主分析粒度L3。';

-- ############################################################
-- 6. get_product_period_summary: 商品拆分
-- 规则: carrier_type=全部 为平台独立TOTAL(商品总览优先读取);
--       禁止 商品卡+图文+直播+短视频 重建全部;
--       product_id 与 product_name 同时传必须校验一致
-- ############################################################
CREATE OR REPLACE FUNCTION mart.get_product_period_summary(
    p_shop_name     text DEFAULT NULL,
    p_start_date    date DEFAULT NULL,
    p_end_date      date DEFAULT NULL,
    p_product_id    text DEFAULT NULL,
    p_product_name  text DEFAULT NULL,
    p_carrier_type  text DEFAULT NULL
) RETURNS TABLE(
    shop_name character varying,
    start_date date,
    end_date date,
    day_count integer,
    product_id character varying,
    product_name text,
    carrier_type character varying,
    -- SUM
    user_pay_amount numeric,
    refund_amount_pay_time numeric,
    smart_coupon_amount numeric,
    platform_subsidy_amount numeric,
    -- ratio (V1.4)
    refund_rate_pay_time numeric,           -- 92
    -- source_only (缺基础字段)
    avg_transaction_order_amount numeric,   -- 90
    click_to_transaction_rate_events numeric, -- 91
    source_only_note text
) AS $$
DECLARE
    v_single_day boolean;
    v_cnt bigint;
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION '参数错误: p_start_date 和 p_end_date 不能为空';
    END IF;
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION '参数错误: p_start_date(%) 不能晚于 p_end_date(%)', p_start_date, p_end_date;
    END IF;
    v_single_day := (p_start_date = p_end_date);

    -- product_id 与 product_name 同时传时必须校验指向同一商品
    IF p_product_id IS NOT NULL AND p_product_name IS NOT NULL THEN
        SELECT count(DISTINCT p.product_name) INTO v_cnt
        FROM core.douyin_product_daily p
        WHERE p.product_id = p_product_id AND p.product_name = p_product_name;
        IF v_cnt = 0 THEN
            RAISE EXCEPTION '参数错误: product_id(%) 与 product_name(%) 不匹配同一商品', p_product_id, p_product_name;
        END IF;
    END IF;

    RETURN QUERY
    SELECT
        s.shop_name, p_start_date, p_end_date,
        (p_end_date - p_start_date + 1)::int,
        p.product_id::varchar, p.product_name, p.carrier_type::varchar,
        SUM(p.user_pay_amount),
        SUM(p.refund_amount_pay_time),
        SUM(p.smart_coupon_amount),
        SUM(p.platform_subsidy_amount),
        SUM(p.refund_amount_pay_time) / NULLIF(SUM(p.user_pay_amount), 0),
        CASE WHEN v_single_day THEN MAX(p.avg_transaction_order_amount) ELSE NULL END,
        CASE WHEN v_single_day THEN MAX(p.click_to_transaction_rate_events) ELSE NULL END,
        CASE WHEN v_single_day THEN '单日: source_only返回当天源值'
             ELSE '多日: 成交笔单价/点击成交转化率(缺基础字段)不可跨期重算, 返回NULL' END
    FROM core.douyin_product_daily p
    JOIN meta.shop s ON p.shop_id = s.shop_id
    WHERE (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND (p_product_id IS NULL OR p.product_id = p_product_id)
      AND (p_product_name IS NULL OR p.product_name = p_product_name)
      -- 载体: 未指定时只读独立TOTAL行(全部); 指定时读对应明细载体
      AND ((p_carrier_type IS NULL AND p.carrier_type = '全部')
        OR (p_carrier_type IS NOT NULL AND p.carrier_type = p_carrier_type))
      AND p.biz_date BETWEEN p_start_date AND p_end_date
    GROUP BY s.shop_name, p.product_id, p.product_name, p.carrier_type;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mart.get_product_period_summary(text,date,date,text,text,text) IS
'商品动态区间汇总。carrier_type=全部为平台独立TOTAL(总览优先); 禁止明细载体重建全部; product_id与product_name同时传需一致。';

-- ############################################################
-- 7. get_price_band_period_summary: 价格带拆分
-- 规则: 6个价格带已验证互斥, 可安全SUM重建店铺总量(diff=0.00)
-- ############################################################
CREATE OR REPLACE FUNCTION mart.get_price_band_period_summary(
    p_shop_name   text DEFAULT NULL,
    p_start_date  date DEFAULT NULL,
    p_end_date    date DEFAULT NULL,
    p_price_band  text DEFAULT NULL
) RETURNS TABLE(
    shop_name character varying,
    start_date date,
    end_date date,
    day_count integer,
    price_band character varying,
    -- SUM
    user_pay_amount numeric,
    -- source_only (缺基础字段)
    avg_transaction_order_amount numeric,   -- 93
    click_to_transaction_rate_events numeric, -- 94
    source_only_note text
) AS $$
DECLARE v_single_day boolean;
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION '参数错误: p_start_date 和 p_end_date 不能为空';
    END IF;
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION '参数错误: p_start_date(%) 不能晚于 p_end_date(%)', p_start_date, p_end_date;
    END IF;
    v_single_day := (p_start_date = p_end_date);

    RETURN QUERY
    SELECT
        s.shop_name, p_start_date, p_end_date,
        (p_end_date - p_start_date + 1)::int,
        p.price_band::varchar,
        SUM(p.user_pay_amount),
        CASE WHEN v_single_day THEN MAX(p.avg_transaction_order_amount) ELSE NULL END,
        CASE WHEN v_single_day THEN MAX(p.click_to_transaction_rate_events) ELSE NULL END,
        CASE WHEN v_single_day THEN '单日: source_only返回当天源值'
             ELSE '多日: 成交笔单价/点击成交转化率(缺基础字段)不可跨期重算, 返回NULL' END
    FROM core.douyin_price_band_daily p
    JOIN meta.shop s ON p.shop_id = s.shop_id
    WHERE (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND (p_price_band IS NULL OR p.price_band = p_price_band)
      AND p.biz_date BETWEEN p_start_date AND p_end_date
    GROUP BY s.shop_name, p.price_band;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mart.get_price_band_period_summary(text,date,date,text) IS
'价格带动态区间汇总。6个价格带互斥可安全SUM重建店铺总量(diff=0.00)。';

-- ############################################################
-- 8. get_audience_period_summary: 人群拆分
-- 规则: carrier_type=全部 为合法TOTAL(总览优先); 拆分只取5载体明细;
--       禁止 TOTAL+DETAIL 一起SUM
-- ############################################################
CREATE OR REPLACE FUNCTION mart.get_audience_period_summary(
    p_shop_name     text DEFAULT NULL,
    p_start_date    date DEFAULT NULL,
    p_end_date      date DEFAULT NULL,
    p_audience_type text DEFAULT NULL,
    p_carrier_type  text DEFAULT NULL
) RETURNS TABLE(
    shop_name character varying,
    start_date date,
    end_date date,
    day_count integer,
    audience_type character varying,
    carrier_type character varying,
    -- SUM
    user_pay_amount numeric,
    transaction_buyer_count numeric,
    transaction_order_count numeric,
    -- ratio (V1.4)
    avg_customer_amount numeric,            -- 95
    -- source_only (缺基础字段)
    repeat_user_repeat_rate numeric,        -- 96
    source_only_note text
) AS $$
DECLARE v_single_day boolean;
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION '参数错误: p_start_date 和 p_end_date 不能为空';
    END IF;
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION '参数错误: p_start_date(%) 不能晚于 p_end_date(%)', p_start_date, p_end_date;
    END IF;
    v_single_day := (p_start_date = p_end_date);

    RETURN QUERY
    SELECT
        s.shop_name, p_start_date, p_end_date,
        (p_end_date - p_start_date + 1)::int,
        a.audience_type::varchar, a.carrier_type::varchar,
        SUM(a.user_pay_amount),
        SUM(a.transaction_buyer_count),
        SUM(a.transaction_order_count),
        SUM(a.user_pay_amount) / NULLIF(SUM(a.transaction_buyer_count), 0),
        CASE WHEN v_single_day THEN MAX(a.repeat_user_repeat_rate) ELSE NULL END,
        CASE WHEN v_single_day THEN '单日: source_only返回当天源值'
             ELSE '多日: 复购用户复购率(缺基础字段)不可跨期重算, 返回NULL' END
    FROM core.douyin_audience_daily a
    JOIN meta.shop s ON a.shop_id = s.shop_id
    WHERE (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND (p_audience_type IS NULL OR a.audience_type = p_audience_type)
      -- 载体: 未指定时只读TOTAL行(全部); 指定时读对应明细载体
      AND ((p_carrier_type IS NULL AND a.carrier_type = '全部')
        OR (p_carrier_type IS NOT NULL AND a.carrier_type = p_carrier_type))
      AND a.biz_date BETWEEN p_start_date AND p_end_date
    GROUP BY s.shop_name, a.audience_type, a.carrier_type;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mart.get_audience_period_summary(text,date,date,text,text) IS
'人群动态区间汇总。carrier_type=全部为合法TOTAL(60/60天验证diff=0); 拆分只取5载体明细; 禁止TOTAL+DETAIL混SUM。';
