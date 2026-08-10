-- mart V1.0 阶段1 第三部分：Scope Resolver
-- 基础语义治理与过滤规则解析（不做完整动态经营汇总引擎）
BEGIN;

-- ============ 1. 语义 → 过滤条件 解析函数 ============
CREATE OR REPLACE FUNCTION mart.resolve_scope(
    p_scope VARCHAR  -- 全店/自营/合作/商品卡/短视频/直播/图文/其他/自营商品卡/合作短视频...
)
RETURNS TABLE(
    scope_semantic VARCHAR,
    sale_scope VARCHAR,
    carrier_type VARCHAR,
    ad_period VARCHAR,
    is_total BOOLEAN,
    rule_note TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sale VARCHAR := NULL;
    v_carrier VARCHAR := NULL;
    v_period VARCHAR := '不限';
    v_total BOOLEAN := FALSE;
    v_note TEXT := '';
BEGIN
    -- 规范化输入
    p_scope := NULLIF(TRIM(p_scope), '');
    IF p_scope IS NULL OR p_scope = '全店' THEN
        v_sale := '全部'; v_carrier := '全部'; v_total := TRUE;
        v_note := '平台合法TOTAL：sale_scope=全部, carrier=全部, ad_period=不限';
    ELSIF p_scope = '自营' THEN
        v_sale := '自营'; v_carrier := '全部';
        v_note := '自营总览：carrier=全部(平台TOTAL)';
    ELSIF p_scope = '合作' THEN
        v_sale := '合作'; v_carrier := '全部';
        v_note := '合作总览：carrier=全部(平台TOTAL)';
    ELSIF p_scope = '商品卡' THEN
        v_sale := '全部'; v_carrier := '商品卡';
        v_note := '全部商品卡：sale_scope=全部, carrier=商品卡';
    ELSIF p_scope = '短视频' THEN
        v_sale := '全部'; v_carrier := '短视频';
        v_note := '全部短视频：sale_scope=全部, carrier=短视频';
    ELSIF p_scope = '直播' THEN
        v_sale := '全部'; v_carrier := '直播';
        v_note := '全部直播：sale_scope=全部, carrier=直播';
    ELSIF p_scope = '图文' THEN
        v_sale := '全部'; v_carrier := '图文';
        v_note := '全部图文：sale_scope=全部, carrier=图文';
    ELSIF p_scope = '其他' THEN
        v_sale := '全部'; v_carrier := '其他';
        v_note := '全部其他：sale_scope=全部, carrier=其他';
    ELSIF p_scope = '自营商品卡' THEN
        v_sale := '自营'; v_carrier := '商品卡';
        v_note := '自营×商品卡组合';
    ELSIF p_scope = '合作商品卡' THEN
        v_sale := '合作'; v_carrier := '商品卡';
        v_note := '合作×商品卡组合';
    ELSIF p_scope = '自营短视频' THEN
        v_sale := '自营'; v_carrier := '短视频';
        v_note := '自营×短视频组合';
    ELSIF p_scope = '合作短视频' THEN
        v_sale := '合作'; v_carrier := '短视频';
        v_note := '合作×短视频组合';
    ELSIF p_scope = '自营直播' THEN
        v_sale := '自营'; v_carrier := '直播';
        v_note := '自营×直播组合';
    ELSIF p_scope = '合作直播' THEN
        v_sale := '合作'; v_carrier := '直播';
        v_note := '合作×直播组合';
    ELSIF p_scope = '自营图文' THEN
        v_sale := '自营'; v_carrier := '图文';
        v_note := '自营×图文组合';
    ELSIF p_scope = '合作图文' THEN
        v_sale := '合作'; v_carrier := '图文';
        v_note := '合作×图文组合';
    ELSE
        RAISE EXCEPTION '未识别经营语义: %', p_scope;
    END IF;

    RETURN QUERY SELECT p_scope, v_sale, v_carrier, v_period, v_total, v_note;
END;
$$;

COMMENT ON FUNCTION mart.resolve_scope(VARCHAR) IS 'Scope Resolver：将经营语义（全店/自营/合作/载体/组合）解析为真实过滤条件；TOTAL优先平台合法口径，禁止父级+子级SUM。';

-- ============ 2. 常用口径快速查询函数（验证用） ============
CREATE OR REPLACE FUNCTION mart.scope_daily(
    p_scope VARCHAR,
    p_date_from DATE,
    p_date_to DATE
)
RETURNS TABLE(
    shop_name VARCHAR,
    biz_date DATE,
    sale_scope VARCHAR,
    carrier_type VARCHAR,
    ad_period VARCHAR,
    user_pay_amount NUMERIC,
    transaction_amount NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sale VARCHAR;
    v_carrier VARCHAR;
    v_period VARCHAR;
    v_total BOOLEAN;
BEGIN
    SELECT r.sale_scope, r.carrier_type, r.ad_period, r.is_total
    INTO v_sale, v_carrier, v_period, v_total
    FROM mart.resolve_scope(p_scope) r;

    RETURN QUERY
    SELECT s.shop_name, d.biz_date, d.sale_scope, d.carrier_type, d.ad_period,
           d.user_pay_amount, d.transaction_amount
    FROM core.douyin_deal_daily d
    JOIN meta.shop s ON d.shop_id = s.shop_id
    WHERE d.sale_scope = v_sale
      AND d.carrier_type = v_carrier
      AND d.ad_period = v_period
      AND d.biz_date BETWEEN p_date_from AND p_date_to
    ORDER BY d.biz_date;
END;
$$;

COMMENT ON FUNCTION mart.scope_daily(VARCHAR, DATE, DATE) IS '按经营语义查询每日数据（使用deal_daily合法TOTAL/明细口径）。';

COMMIT;

-- 验证
SELECT * FROM mart.resolve_scope('全店');
SELECT * FROM mart.resolve_scope('自营商品卡');
