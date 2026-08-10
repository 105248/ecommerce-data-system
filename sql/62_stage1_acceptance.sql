-- mart V1.0 阶段1 第七部分：验收
-- 1. core总行数
SELECT '1.core总行数' AS chk, (SELECT count(*) FROM core.douyin_deal_daily) +
    (SELECT count(*) FROM core.douyin_carrier_daily) + (SELECT count(*) FROM core.douyin_account_daily) +
    (SELECT count(*) FROM core.douyin_content_daily) + (SELECT count(*) FROM core.douyin_terminal_daily) +
    (SELECT count(*) FROM core.douyin_category_daily) + (SELECT count(*) FROM core.douyin_product_daily) +
    (SELECT count(*) FROM core.douyin_price_band_daily) + (SELECT count(*) FROM core.douyin_audience_daily)::text AS val;

-- 2/3. shop_daily 行数+唯一性
SELECT '2/3.shop_daily' AS chk, count(*)::text || '行/唯一' || count(DISTINCT (shop_name, biz_date))::text AS val FROM mart.shop_daily;

-- 4. shop_daily金额 vs deal合法TOTAL
SELECT '4.shop_daily金额核对' AS chk,
    (SELECT round(SUM(user_pay_amount),2)::text FROM mart.shop_daily) || ' = ' ||
    (SELECT round(SUM(user_pay_amount),2)::text FROM core.douyin_deal_daily
     WHERE sale_scope='全部' AND carrier_type='全部' AND ad_period='不限') AS val;

-- 5. carrier/account 不提供全店TOTAL (检查无'全部'sale_scope)
SELECT '5.carrier无全部scope' AS chk, count(*)::text AS val FROM mart.carrier_daily WHERE sale_scope = '全部';
SELECT '5b.account无全部' AS chk, count(*)::text AS val FROM mart.account_daily WHERE sale_scope = '全部';

-- 6. product 不混SUM (carrier=全部行不参与明细SUM — 校验独立)
SELECT '6.product独立total' AS chk, count(*)::text AS val FROM mart.product_daily WHERE carrier_type = '全部';

-- 7. terminal 整体+明细不混 (检查整体行存在)
SELECT '7.terminal整体行' AS chk, count(*)::text AS val FROM mart.terminal_daily WHERE terminal_type = '整体';

-- 8. audience carrier=全部存在
SELECT '8.audience全部行' AS chk, count(*)::text AS val FROM mart.audience_daily WHERE carrier_type = '全部';

-- 9. price_band 6带求和 vs deal
SELECT '9.price_band求和' AS chk,
    (SELECT round(SUM(user_pay_amount),2)::text FROM mart.price_band_daily) || ' vs ' ||
    (SELECT round(SUM(user_pay_amount),2)::text FROM mart.shop_daily) AS val;

-- 10. category 层级不混
SELECT '10.category层级' AS chk, string_agg(category_level::text || '=' || cnt::text, ',') AS val
FROM (SELECT category_level, count(*) AS cnt FROM mart.category_daily GROUP BY category_level) x;

-- 11. mart显示shop_name
SELECT '11.mart显示shop_name' AS chk, count(*)::text AS val
FROM information_schema.columns WHERE table_schema='mart' AND table_name IN
    ('shop_daily','carrier_daily','account_daily','content_daily','terminal_daily','category_daily','product_daily','price_band_daily','audience_daily')
    AND column_name = 'shop_name';

-- 12. 中文View显示店铺名称
SELECT '12.中文View店铺名称' AS chk, count(*)::text AS val
FROM information_schema.columns WHERE table_schema='中文数据' AND column_name='店铺名称'
    AND table_name IN ('店铺每日总览','载体构成分析','账号构成分析','单载体内容分析','终端构成分析','品类构成分析','商品构成分析','价格带构成分析','人群构成分析');

-- 13. 比例原值
SELECT '13.比例原值' AS chk, "商品点击-成交转化率(人数)"::text AS val
FROM "中文数据"."抖音成交日报" WHERE "源文件行号" = 8 AND "成交范围" = '全部';
