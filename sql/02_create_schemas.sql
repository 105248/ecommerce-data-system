-- ============================================================
-- ecommerce-data-system · 五层 Schema 初始化脚本
-- 文件: 02_create_schemas.sql
-- 作用: 创建 meta / audit / stg / core / mart 五个数据分层
-- 执行方式: psql -U postgres -d ecommerce_db -f 02_create_schemas.sql
--           (Docker 自动执行时通过 \connect 切到 ecommerce_db)
-- ============================================================

\connect ecommerce_db

CREATE SCHEMA IF NOT EXISTS meta;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS mart;

COMMENT ON SCHEMA meta IS
'基础资料层：保存平台、店铺、指标字典、字段映射等基础配置。';

COMMENT ON SCHEMA audit IS
'审计记录层：保存文件导入批次、错误信息、处理结果和操作日志。';

COMMENT ON SCHEMA stg IS
'临时数据层：Excel文件读取后先进入此层，校验通过后再写入正式数据表。';

COMMENT ON SCHEMA core IS
'标准数据层：保存清洗完成、去重完成、可用于分析的正式日维度数据。';

COMMENT ON SCHEMA mart IS
'经营分析层：保存给WorkBuddy、OpenClaw和MCP查询的业务视图。';
