-- 阶段2探查4: resolve_scope 源码 + deal_daily 完整字段
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname='mart' AND p.proname='resolve_scope';

\echo ====== deal_daily 全部字段 ======
SELECT column_name FROM information_schema.columns
WHERE table_schema='core' AND table_name='douyin_deal_daily' ORDER BY ordinal_position;
