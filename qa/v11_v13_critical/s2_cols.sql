\pset pager off
\echo '=== anomaly_rule 列 ==='
SELECT column_name FROM information_schema.columns WHERE table_schema='mart' AND table_name='anomaly_rule' ORDER BY ordinal_position;
\echo '=== anomaly_event 列 ==='
SELECT column_name FROM information_schema.columns WHERE table_schema='mart' AND table_name='anomaly_event' ORDER BY ordinal_position;
\echo '=== opportunity_rule 列 ==='
SELECT column_name FROM information_schema.columns WHERE table_schema='mart' AND table_name='opportunity_rule' ORDER BY ordinal_position;
\echo '=== opportunity_event 列 ==='
SELECT column_name FROM information_schema.columns WHERE table_schema='mart' AND table_name='opportunity_event' ORDER BY ordinal_position;
\echo '=== diagnostic_result 列 ==='
SELECT column_name FROM information_schema.columns WHERE table_schema='mart' AND table_name='diagnostic_result' ORDER BY ordinal_position;
\echo '=== daily_action_item 列 ==='
SELECT column_name FROM information_schema.columns WHERE table_schema='mart' AND table_name='daily_action_item' ORDER BY ordinal_position;
