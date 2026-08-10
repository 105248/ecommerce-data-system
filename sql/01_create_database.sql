-- ============================================================
-- ecommerce-data-system · 数据库初始化脚本
-- 文件: 01_create_database.sql
-- 作用: 创建 ecommerce_db 数据库
-- 执行方式:
--   Windows原生: psql -U postgres -f 01_create_database.sql
--   Docker方式:  POSTGRES_DB=ecommerce_db 已在 compose 中创建，
--                此文件在容器中自动跳过（数据库已存在）
-- ============================================================

-- 幂等创建：数据库已存在时给出提示，不报错中断
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'ecommerce_db') THEN
        CREATE DATABASE ecommerce_db
            WITH
            ENCODING = 'UTF8'
            TEMPLATE = template0;
    ELSE
        RAISE NOTICE '数据库 ecommerce_db 已存在，跳过创建。';
    END IF;
END
$$;
