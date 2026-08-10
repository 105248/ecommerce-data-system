-- 中文可读层 V1.1：覆盖率检查 + 刷新机制
BEGIN;

-- ============ 1. check_chinese_coverage() ============
CREATE OR REPLACE FUNCTION meta.check_chinese_coverage()
RETURNS TABLE(
    check_item TEXT,
    result TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_tables INT;
    v_cn_tables INT;
    v_total_cols INT;
    v_cn_cols INT;
    v_conflicts INT;
    v_dup_cols INT;
BEGIN
    -- 对象覆盖率（core+meta+audit 物理表 vs 中文View）
    SELECT count(*) INTO v_total_tables
    FROM information_schema.tables
    WHERE table_schema IN ('core','meta','audit') AND table_type = 'BASE TABLE';

    SELECT count(*) INTO v_cn_tables
    FROM information_schema.views WHERE table_schema = '中文数据';

    -- 字段覆盖率（core 9表）
    SELECT count(*) INTO v_total_cols
    FROM information_schema.columns
    WHERE table_schema = 'core';

    SELECT count(*) INTO v_cn_cols
    FROM information_schema.columns
    WHERE table_schema = '中文数据'
      AND table_name IN ('抖音成交日报','抖音载体日报','抖音账号日报','抖音内容日报',
                         '抖音终端日报','抖音类目日报','抖音商品日报','抖音价格带日报','抖音人群日报');

    -- 冲突
    SELECT count(*) INTO v_conflicts
    FROM meta.database_object_dictionary
    WHERE name_resolution_status = 'conflict_pending' AND enabled = TRUE;

    -- 中文View内重复列名（中文数据 schema 内重名列）
    SELECT count(*) INTO v_dup_cols
    FROM (
        SELECT table_name, column_name, count(*) AS c
        FROM information_schema.columns
        WHERE table_schema = '中文数据'
        GROUP BY table_name, column_name
        HAVING count(*) > 1
    ) x;

    RETURN QUERY SELECT '业务对象(物理表数)', v_total_tables::text;
    RETURN QUERY SELECT '中文View数', v_cn_tables::text;
    RETURN QUERY SELECT 'core字段总数', v_total_cols::text;
    RETURN QUERY SELECT 'core中文字段数', v_cn_cols::text;
    RETURN QUERY SELECT '字段覆盖率', round(v_cn_cols::numeric / NULLIF(v_total_cols,0) * 100, 2)::text || '%';
    RETURN QUERY SELECT '冲突待决数', v_conflicts::text;
    RETURN QUERY SELECT '中文View重名列数', v_dup_cols::text;
END;
$$;

COMMENT ON FUNCTION meta.check_chinese_coverage() IS '中文可读层覆盖率检查：对象/字段覆盖率、冲突数、重名列数。';

-- ============ 2. refresh_chinese_views() ============
CREATE OR REPLACE FUNCTION meta.refresh_chinese_views()
RETURNS TABLE(result TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
    col_rec RECORD;
    cols TEXT := '';
    first BOOLEAN := TRUE;
    v_conflicts INT;
BEGIN
    -- 冲突检查：存在 conflict_pending 则禁止刷新
    SELECT count(*) INTO v_conflicts
    FROM meta.database_object_dictionary
    WHERE name_resolution_status = 'conflict_pending' AND enabled = TRUE;
    IF v_conflicts > 0 THEN
        RETURN QUERY SELECT 'ERROR: 存在 ' || v_conflicts::text || ' 条冲突待决，禁止刷新中文View';
        RETURN;
    END IF;

    -- 遍历所有已登记的中文表对象
    FOR rec IN
        SELECT DISTINCT schema_name, object_name, object_name_cn
        FROM meta.database_object_dictionary
        WHERE object_type = 'table' AND enabled = TRUE AND object_name_cn IS NOT NULL
        ORDER BY object_name_cn
    LOOP
        cols := '';
        first := TRUE;
        -- 收集字段（按 display_order 顺序）
        FOR col_rec IN
            SELECT column_name, column_name_cn
            FROM meta.database_object_dictionary
            WHERE schema_name = rec.schema_name AND object_name = rec.object_name
              AND object_type = 'column' AND enabled = TRUE AND visible_in_cn_view = TRUE
            ORDER BY display_order NULLS LAST, column_name
        LOOP
            IF NOT first THEN cols := cols || ','; END IF;
            cols := cols || '    ' || col_rec.column_name || ' AS "' || col_rec.column_name_cn || '"';
            first := FALSE;
        END LOOP;

        IF cols = '' THEN
            RETURN QUERY SELECT 'SKIP: ' || rec.object_name_cn || '（无字段）';
            CONTINUE;
        END IF;

        -- 重建View（仅中文数据 schema 内）
        EXECUTE format(
            'CREATE OR REPLACE VIEW "中文数据"."%s" AS SELECT %s FROM %s.%s;',
            rec.object_name_cn, cols, rec.schema_name, rec.object_name
        );
        RETURN QUERY SELECT 'OK: 已刷新 ' || rec.object_name_cn;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION meta.refresh_chinese_views() IS '中文View刷新机制：仅读取字典元数据，仅在中文数据Schema内重建View；存在冲突则停止。';

-- ============ 3. 更新字典 display_order（按物理列顺序） ============
UPDATE meta.database_object_dictionary d
SET display_order = c.ordinal_position
FROM information_schema.columns c
WHERE d.schema_name = c.table_schema
  AND d.object_name = c.table_name
  AND d.column_name = c.column_name
  AND d.object_type = 'column';

COMMIT;

-- 验证
SELECT * FROM meta.check_chinese_coverage();
