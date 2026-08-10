-- 修正 batch 7 的空字段（文件名和源行数，程序修复后下次自动正确）
UPDATE audit.import_batch
SET source_file_name = '抖音电商罗盘-成交分析-20260601-20260630.xlsx',
    source_row_count = 18809
WHERE batch_id = 7;

-- 确认
SELECT batch_id, platform_code, shop_id, source_file_name,
       file_sha256, period_start, period_end, import_mode,
       import_status, source_row_count, inserted_row_count,
       COALESCE(error_message, '') AS error_message
FROM audit.import_batch
WHERE batch_id = 7;
