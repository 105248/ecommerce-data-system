-- ============================================================
-- ecommerce-data-system · 店铺资料表
-- 文件: 03_meta_shop.sql
-- 作用: 创建 meta.shop 店铺基础资料表 + 登记弹动官方旗舰店
-- 执行方式: psql -U postgres -d ecommerce_db -f 03_meta_shop.sql
--           (Docker 自动执行时通过 \connect 切到 ecommerce_db)
-- ============================================================

\connect ecommerce_db

-- 店铺基础资料表
CREATE TABLE meta.shop (
    shop_id              BIGSERIAL PRIMARY KEY,
    platform_code        VARCHAR(30) NOT NULL,
    shop_code            VARCHAR(50) NOT NULL,
    shop_name            VARCHAR(100) NOT NULL,
    platform_shop_id     VARCHAR(100),
    enabled              BOOLEAN NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uk_shop_code UNIQUE (platform_code, shop_code)
);

COMMENT ON TABLE meta.shop IS
'店铺基础资料表：统一登记抖音、天猫、京东等平台的所有店铺。';

COMMENT ON COLUMN meta.shop.shop_id IS
'店铺内部ID：数据库自动生成的唯一编号。';

COMMENT ON COLUMN meta.shop.platform_code IS
'平台编码：例如douyin代表抖音，tmall代表天猫，jd代表京东。';

COMMENT ON COLUMN meta.shop.shop_code IS
'店铺内部编码：企业自己制定的稳定店铺编码，不随店铺名称变化。';

COMMENT ON COLUMN meta.shop.shop_name IS
'店铺名称：平台上显示的正式店铺名称。';

COMMENT ON COLUMN meta.shop.platform_shop_id IS
'平台店铺ID：抖音、天猫等平台提供的店铺唯一编号，没有时可以暂时为空。';

COMMENT ON COLUMN meta.shop.enabled IS
'是否启用：TRUE表示正常使用，FALSE表示停止导入和查询。';

COMMENT ON COLUMN meta.shop.created_at IS
'创建时间：店铺资料写入数据库的时间。';

-- 登记第一个抖音店铺：弹动官方旗舰店
INSERT INTO meta.shop (
    platform_code,
    shop_code,
    shop_name
)
VALUES (
    'douyin',
    'DY_DANDONG_OFFICIAL',
    '弹动官方旗舰店'
);
