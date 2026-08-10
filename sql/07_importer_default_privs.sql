-- 在 ecommerce_db 库内补齐默认权限（连接库后执行）
\connect ecommerce_db

-- meta 层默认权限
ALTER DEFAULT PRIVILEGES IN SCHEMA meta GRANT SELECT ON TABLES TO ecommerce_importer;
-- audit 层默认权限
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT SELECT, INSERT, UPDATE ON TABLES TO ecommerce_importer;
-- stg 层默认权限
ALTER DEFAULT PRIVILEGES IN SCHEMA stg GRANT ALL ON TABLES TO ecommerce_importer;
ALTER DEFAULT PRIVILEGES IN SCHEMA stg GRANT ALL ON SEQUENCES TO ecommerce_importer;
-- core 层默认权限
ALTER DEFAULT PRIVILEGES IN SCHEMA core GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ecommerce_importer;
ALTER DEFAULT PRIVILEGES IN SCHEMA core GRANT USAGE, SELECT ON SEQUENCES TO ecommerce_importer;

-- 实际表权限（对已存在的表补一遍，双保险）
GRANT SELECT ON ALL TABLES IN SCHEMA meta TO ecommerce_importer;
GRANT SELECT, INSERT, UPDATE ON audit.import_batch TO ecommerce_importer;
GRANT USAGE, SELECT ON SEQUENCE audit.import_batch_batch_id_seq TO ecommerce_importer;
GRANT ALL ON ALL TABLES IN SCHEMA stg TO ecommerce_importer;
GRANT ALL ON ALL SEQUENCES IN SCHEMA stg TO ecommerce_importer;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA core TO ecommerce_importer;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA core TO ecommerce_importer;

-- 确认权限
SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema='core' AND grantee='ecommerce_importer'
ORDER BY table_name, privilege_type LIMIT 20;
