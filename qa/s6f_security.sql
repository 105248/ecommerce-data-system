-- 阶段6F-3: agent_readonly 只读安全测试(以只读身份执行, 8项)
\echo ===== 1. SELECT(应成功) =====
SELECT shop_name FROM meta.shop;
\echo ===== 2. EXECUTE批准Function(应成功) =====
SELECT user_pay_amount FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店');
\echo ===== 3. INSERT(应失败) =====
INSERT INTO core.douyin_deal_daily (shop_id,biz_date,sale_scope,carrier_type,ad_period,user_pay_amount) VALUES (1,'2026-06-01','全部','全部','不限',0);
\echo ===== 4. UPDATE(应失败) =====
UPDATE meta.shop SET shop_name=shop_name WHERE shop_id=1;
\echo ===== 5. DELETE(应失败) =====
DELETE FROM meta.shop WHERE shop_id=1;
\echo ===== 6. TRUNCATE(应失败) =====
TRUNCATE meta.shop;
\echo ===== 7. CREATE TABLE(应失败) =====
CREATE TABLE tmp_stage6_hack(id int);
\echo ===== 8. DROP TABLE(应失败) =====
DROP TABLE IF EXISTS meta.shop;
\echo ===== 9. ALTER TABLE(应失败) =====
ALTER TABLE meta.shop ADD COLUMN tmp_col int;
