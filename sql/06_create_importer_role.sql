-- 创建专用导入账号 ecommerce_importer
-- 密码从参数文件读取（由 Python 脚本生成后传入）

CREATE ROLE ecommerce_importer WITH LOGIN PASSWORD :'pw' NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- 连接权限
GRANT CONNECT ON DATABASE ecommerce_db TO ecommerce_importer;

-- meta 层：只读（shop / source_sheet_mapping / field_mapping）
GRANT USAGE ON SCHEMA meta TO ecommerce_importer;
GRANT SELECT ON ALL TABLES IN SCHEMA meta TO ecommerce_importer;
ALTER DEFAULT PRIVILEGES IN SCHEMA meta GRANT SELECT ON TABLES TO ecommerce_importer;

-- audit 层：import_batch 可增改查
GRANT USAGE ON SCHEMA audit TO ecommerce_importer;
GRANT SELECT, INSERT, UPDATE ON audit.import_batch TO ecommerce_importer;
GRANT USAGE, SELECT ON SEQUENCE audit.import_batch_batch_id_seq TO ecommerce_importer;

-- stg 层：完全使用（导入中间暂存）
GRANT USAGE ON SCHEMA stg TO ecommerce_importer;
GRANT ALL ON ALL TABLES IN SCHEMA stg TO ecommerce_importer;
ALTER DEFAULT PRIVILEGES IN SCHEMA stg GRANT ALL ON TABLES TO ecommerce_importer;
GRANT ALL ON ALL SEQUENCES IN SCHEMA stg TO ecommerce_importer;

-- core 层：9 张正式表增删改查 + sequence
GRANT USAGE ON SCHEMA core TO ecommerce_importer;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA core TO ecommerce_importer;
ALTER DEFAULT PRIVILEGES IN SCHEMA core GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ecommerce_importer;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA core TO ecommerce_importer;
ALTER DEFAULT PRIVILEGES IN SCHEMA core GRANT USAGE, SELECT ON SEQUENCES TO ecommerce_importer;

-- 明确禁止：不允许在 meta/core 之外创建对象（仅 stg 可）
REVOKE CREATE ON SCHEMA meta FROM ecommerce_importer;
REVOKE CREATE ON SCHEMA core FROM ecommerce_importer;
REVOKE CREATE ON SCHEMA audit FROM ecommerce_importer;
