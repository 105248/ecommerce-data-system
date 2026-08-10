-- 将 batch 6 标记为 failed（调试期间手工清空数据，无效成功）
UPDATE audit.import_batch
SET import_status = 'failed',
    error_message = '调试期间手工清空数据，标记无效成功'
WHERE batch_id = 6;
