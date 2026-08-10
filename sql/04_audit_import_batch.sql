-- ============================================================
-- ecommerce-data-system · 数据导入批次表
-- 文件: 04_audit_import_batch.sql
-- 作用: 创建 audit.import_batch 导入批次审计表
-- 执行方式: psql -U postgres -d ecommerce_db -f 04_audit_import_batch.sql
--           (Docker 自动执行时通过 \connect 切到 ecommerce_db)
-- ============================================================

\connect ecommerce_db

-- 数据导入批次表
CREATE TABLE audit.import_batch (
    batch_id              BIGSERIAL PRIMARY KEY,
    platform_code         VARCHAR(30) NOT NULL,
    shop_id               BIGINT NOT NULL,
    source_file_name      VARCHAR(255) NOT NULL,
    source_file_path      TEXT,
    file_sha256           CHAR(64),
    period_start          DATE,
    period_end            DATE,
    import_mode           VARCHAR(30) NOT NULL DEFAULT 'replace_period',
    import_status         VARCHAR(30) NOT NULL DEFAULT 'pending',
    source_row_count      INTEGER NOT NULL DEFAULT 0,
    inserted_row_count    INTEGER NOT NULL DEFAULT 0,
    error_message         TEXT,
    imported_at           TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_import_batch_shop
        FOREIGN KEY (shop_id)
        REFERENCES meta.shop(shop_id),

    CONSTRAINT ck_import_period
        CHECK (
            period_start IS NULL
            OR period_end IS NULL
            OR period_start <= period_end
        ),

    CONSTRAINT ck_source_row_count
        CHECK (source_row_count >= 0),

    CONSTRAINT ck_inserted_row_count
        CHECK (inserted_row_count >= 0)
);

CREATE INDEX idx_import_batch_shop_date
    ON audit.import_batch(shop_id, period_start, period_end);

CREATE INDEX idx_import_batch_file_sha256
    ON audit.import_batch(file_sha256);

CREATE INDEX idx_import_batch_status
    ON audit.import_batch(import_status);

-- 中文注释
COMMENT ON TABLE audit.import_batch IS
'数据导入批次表：每上传和处理一次Excel文件，就生成一条导入记录，用于追踪文件来源、数据周期、处理状态和错误信息。';

COMMENT ON COLUMN audit.import_batch.batch_id IS
'导入批次ID：每次文件导入的唯一编号，由数据库自动生成。';

COMMENT ON COLUMN audit.import_batch.platform_code IS
'平台编码：标识数据来自抖音、天猫、京东或其他平台。';

COMMENT ON COLUMN audit.import_batch.shop_id IS
'店铺ID：关联店铺基础资料表，用于区分不同店铺的数据。';

COMMENT ON COLUMN audit.import_batch.source_file_name IS
'源文件名称：用户上传或导入的原始Excel文件名称。';

COMMENT ON COLUMN audit.import_batch.source_file_path IS
'源文件路径：原始Excel文件在本地电脑中的保存位置。';

COMMENT ON COLUMN audit.import_batch.file_sha256 IS
'文件SHA256指纹：根据文件内容生成的唯一值，用于识别完全相同的重复文件。';

COMMENT ON COLUMN audit.import_batch.period_start IS
'数据开始日期：该Excel文件中包含数据的最早业务日期。';

COMMENT ON COLUMN audit.import_batch.period_end IS
'数据结束日期：该Excel文件中包含数据的最晚业务日期。';

COMMENT ON COLUMN audit.import_batch.import_mode IS
'导入模式：replace_period表示按店铺和日期范围覆盖原有数据。';

COMMENT ON COLUMN audit.import_batch.import_status IS
'导入状态：pending待处理、processing处理中、success成功、failed失败、cancelled取消。';

COMMENT ON COLUMN audit.import_batch.source_row_count IS
'源数据行数：Excel各工作表中读取到的有效数据总行数。';

COMMENT ON COLUMN audit.import_batch.inserted_row_count IS
'成功写入行数：完成清洗后实际写入正式数据表的数据行数。';

COMMENT ON COLUMN audit.import_batch.error_message IS
'错误信息：导入失败或数据校验异常时保存具体原因。';

COMMENT ON COLUMN audit.import_batch.imported_at IS
'导入时间：本次导入批次在数据库中创建的时间。';
