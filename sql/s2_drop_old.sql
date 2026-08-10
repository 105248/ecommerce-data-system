-- 删除旧版阶段2函数(返回结构与提供SQL不同, 需先DROP)
DROP FUNCTION IF EXISTS mart.get_business_period_summary(text,date,date,text);
DROP FUNCTION IF EXISTS mart.get_carrier_period_summary(text,date,date,text,text,text);
DROP FUNCTION IF EXISTS mart.get_account_period_summary(text,date,date,text,text);
DROP FUNCTION IF EXISTS mart.get_content_period_summary(text,date,date,text,text,text);
DROP FUNCTION IF EXISTS mart.get_terminal_period_summary(text,date,date,text,text);
DROP FUNCTION IF EXISTS mart.get_product_period_summary(text,date,date,text,text,text);
DROP FUNCTION IF EXISTS mart.get_price_band_period_summary(text,date,date,text);
DROP FUNCTION IF EXISTS mart.get_audience_period_summary(text,date,date,text,text);
DROP FUNCTION IF EXISTS mart.get_category_period_summary(text,date,date,int,text,text,text);
