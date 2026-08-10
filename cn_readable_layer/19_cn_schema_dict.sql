-- 中文可读层 V1.1：创建 中文数据 Schema + meta.database_object_dictionary
BEGIN;

-- 1. 中文数据 Schema
CREATE SCHEMA IF NOT EXISTS "中文数据";
COMMENT ON SCHEMA "中文数据" IS
'业务数据库中文可读层。底层英文物理对象不改变，本Schema中的View用于pgAdmin人工查看和业务核对。';

-- 2. 中英文字典表（可溯源）
CREATE TABLE IF NOT EXISTS meta.database_object_dictionary (
    dictionary_id           BIGSERIAL PRIMARY KEY,
    schema_name             VARCHAR(50) NOT NULL,
    object_name             VARCHAR(150) NOT NULL,
    object_type             VARCHAR(30) NOT NULL DEFAULT 'table',  -- table / view
    object_name_cn          VARCHAR(200),
    column_name             VARCHAR(150),   -- 表级记录可为空
    column_name_cn          VARCHAR(300),
    source_platform         VARCHAR(50) DEFAULT 'douyin',
    source_sheet_name       VARCHAR(200),
    source_field_name_cn    VARCHAR(300),
    source_header_variants  JSONB,
    chinese_name_source     VARCHAR(40) NOT NULL DEFAULT 'source_header',  -- source_header / manual / system_dictionary / comment
    name_resolution_status  VARCHAR(40) NOT NULL DEFAULT 'unique_source_header',  -- unique_source_header / manual_confirmed / system_field / conflict_pending
    is_manual_override      BOOLEAN NOT NULL DEFAULT FALSE,
    override_reason         TEXT,
    business_definition     TEXT,
    display_order           INTEGER,
    visible_in_cn_view      BOOLEAN NOT NULL DEFAULT TRUE,
    mapping_version         VARCHAR(20) NOT NULL DEFAULT 'V1.1',
    enabled                 BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_dict_obj_col UNIQUE (schema_name, object_name, column_name)
);

COMMENT ON TABLE meta.database_object_dictionary IS '全库中英文字典：记录最终显示名称及其来源（原始表头/系统词典/人工覆盖），可溯源。';
COMMENT ON COLUMN meta.database_object_dictionary.source_header_variants IS '同一物理字段对应的所有“工作表→原始表头”，JSONB保留多源信息。';
COMMENT ON COLUMN meta.database_object_dictionary.chinese_name_source IS '名称来源：source_header原始表头/manual人工/system_dictionary系统词典/comment注释。';
COMMENT ON COLUMN meta.database_object_dictionary.name_resolution_status IS '解析状态：unique_source_header唯一表头/manual_confirmed人工确认/system_field系统字段/conflict_pending冲突待决。';

COMMIT;
