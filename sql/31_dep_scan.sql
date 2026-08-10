-- shop_name 冗余列依赖扫描
-- 1. 哪些表存在 shop_name 列
SELECT '存在shop_name列的表' AS chk, table_schema || '.' || table_name AS obj
FROM information_schema.columns
WHERE column_name = 'shop_name' AND table_schema IN ('core','audit')
ORDER BY 2;

-- 2. 是否有 View 依赖 shop_name（中文数据 schema 视图定义）
SELECT 'View依赖shop_name' AS chk, view_schema || '.' || view_name AS obj
FROM information_schema.views
WHERE view_definition LIKE '%shop_name%'
  AND view_schema = '中文数据';

-- 3. 是否有 Function 引用 shop_name
SELECT 'Function引用shop_name' AS chk, p.proname AS obj
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'meta'
  AND pg_get_functiondef(p.oid) LIKE '%shop_name%';

-- 4. 是否有 Index 建立在 shop_name 上
SELECT 'Index在shop_name上' AS chk, schemaname || '.' || indexname AS obj
FROM pg_indexes
WHERE indexdef LIKE '%shop_name%';

-- 5. 是否有 Constraint 涉及 shop_name
SELECT 'Constraint涉及shop_name' AS chk, conname AS obj
FROM pg_constraint
WHERE pg_get_constraintdef(oid) LIKE '%shop_name%';

-- 6. 是否有 Trigger 引用 shop_name
SELECT 'Trigger引用shop_name' AS chk, tgname AS obj
FROM pg_trigger
WHERE tgname LIKE '%shop_name%' OR pg_get_triggerdef(oid) LIKE '%shop_name%';

-- 7. 当前中文View中是否有已显示店铺名称的列（判断之前27/28是否部分成功）
SELECT '当前中文View店铺列' AS chk, table_name || '.' || column_name AS obj
FROM information_schema.columns
WHERE table_schema = '中文数据'
  AND (column_name LIKE '%店铺%')
ORDER BY table_name, ordinal_position;
