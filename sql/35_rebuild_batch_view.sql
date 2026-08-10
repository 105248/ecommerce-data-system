-- 重建 导入批次记录 View（JOIN meta.shop 显示店铺名称）
DROP VIEW IF EXISTS "中文数据"."导入批次记录";

CREATE VIEW "中文数据"."导入批次记录" AS
SELECT
    t.batch_id AS "导入批次ID",
    t.platform_code AS "平台编码",
    s.shop_name AS "店铺名称",
    t.source_file_name AS "源文件名",
    t.source_file_path AS "源文件路径",
    t.file_sha256 AS "文件SHA256",
    t.period_start AS "周期开始",
    t.period_end AS "周期结束",
    t.import_mode AS "导入模式",
    t.import_status AS "导入状态",
    t.source_row_count AS "源文件行数",
    t.inserted_row_count AS "写入行数",
    t.error_message AS "错误信息",
    t.imported_at AS "写入时间"
FROM audit.import_batch t
JOIN meta.shop s ON t.shop_id = s.shop_id;
