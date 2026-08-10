-- 补齐 schema 使用权限（在 ecommerce_db 库内）
\connect ecommerce_db

GRANT USAGE ON SCHEMA meta TO ecommerce_importer;
GRANT USAGE ON SCHEMA audit TO ecommerce_importer;
GRANT USAGE ON SCHEMA stg TO ecommerce_importer;
GRANT USAGE ON SCHEMA core TO ecommerce_importer;

GRANT SELECT ON ALL TABLES IN SCHEMA meta TO ecommerce_importer;
GRANT SELECT, INSERT, UPDATE ON audit.import_batch TO ecommerce_importer;
GRANT USAGE, SELECT ON SEQUENCE audit.import_batch_batch_id_seq TO ecommerce_importer;
GRANT ALL ON ALL TABLES IN SCHEMA stg TO ecommerce_importer;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA core TO ecommerce_importer;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA core TO ecommerce_importer;

-- 验证
SELECT nspname FROM pg_namespace WHERE nspname IN ('meta','audit','stg','core','mart') ORDER BY 1;
