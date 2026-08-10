-- ============================================================================
-- V1.3 阶段2｜抖音多店统一经营层
-- 06_platform_cn_layer.sql（中文数据层：平台经营日报 / 店铺贡献 / 数据覆盖）
-- ============================================================================

DROP VIEW IF EXISTS 中文数据.抖音多店经营日报;
CREATE VIEW 中文数据.抖音多店经营日报 AS
SELECT
    p.biz_date                          AS 日期,
    p.platform_code                     AS 平台,
    p.scope_key                         AS 经营范围,
    p.user_pay_amount                   AS 用户支付金额,
    p.transaction_amount                AS 成交金额,
    p.settlement_amount                 AS 结算金额,
    p.refund_amount_pay_time            AS 退款金额,
    p.transaction_order_count           AS 成交订单数,
    p.transaction_buyer_count           AS 成交人数,
    p.ad_spend_shop_promoted            AS 投放消耗,
    p.ad_attributed_transaction_amount  AS 投放贡献成交金额
FROM mart.douyin_platform_daily p;

COMMENT ON VIEW 中文数据.抖音多店经营日报 IS 'V1.3 平台日表（抖音两店合计，全店口径）。';

DROP VIEW IF EXISTS 中文数据.抖音店铺贡献;
CREATE VIEW 中文数据.抖音店铺贡献 AS
SELECT
    c.platform_name                     AS 平台,
    c.start_date                        AS 开始日期,
    c.end_date                          AS 结束日期,
    c.scope_key                         AS 经营范围,
    c.metric_key                        AS 指标,
    c.shop_name                         AS 店铺名称,
    c.current_value                     AS 本期值,
    c.platform_total                    AS 平台总额,
    c.contribution                      AS 贡献占比,
    c.previous_contribution             AS 上期贡献占比,
    c.contribution_change               AS 贡献变化,
    c.coverage_complete                 AS 覆盖完整
FROM mart.get_shop_contribution('douyin',
     (SELECT min(biz_date) FROM core.douyin_deal_daily),
     (SELECT max(biz_date) FROM core.douyin_deal_daily),
     '全店', 'user_pay_amount') c;

COMMENT ON VIEW 中文数据.抖音店铺贡献 IS 'V1.3 抖音店铺贡献度（默认全月全店 user_pay）。';

DROP VIEW IF EXISTS 中文数据.抖音多店数据覆盖;
CREATE VIEW 中文数据.抖音多店数据覆盖 AS
SELECT
    s.platform_code                     AS 平台,
    s.shop_name                         AS 店铺名称,
    s.enabled                           AS 启用,
    (SELECT min(biz_date)::text FROM core.douyin_deal_daily d WHERE d.shop_id = s.shop_id) AS 最早数据日期,
    (SELECT max(biz_date)::text FROM core.douyin_deal_daily d WHERE d.shop_id = s.shop_id) AS 最晚数据日期,
    (SELECT count(DISTINCT biz_date) FROM core.douyin_deal_daily d WHERE d.shop_id = s.shop_id) AS 有数据天数
FROM meta.shop s
WHERE s.platform_code = 'douyin'
ORDER BY s.shop_id;

COMMENT ON VIEW 中文数据.抖音多店数据覆盖 IS 'V1.3 抖音各店独立数据覆盖（不因他店有数据而误判）。';
