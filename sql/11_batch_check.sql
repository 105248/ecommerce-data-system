-- 第六步: audit.import_batch 验收 (batch_id=7)
SELECT batch_id,
       platform_code,
       shop_id,
       source_file_name,
       source_file_path,
       file_sha256,
       period_start,
       period_end,
       import_mode,
       import_status,
       source_row_count,
       inserted_row_count,
       COALESCE(error_message, '') AS error_message,
       imported_at
FROM audit.import_batch
WHERE batch_id = 7;
