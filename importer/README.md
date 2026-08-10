# 抖音成交分析 Excel 自动导入程序 V1.0

将抖音电商罗盘《成交分析》Excel 自动识别、校验、转换并安全写入现有 PostgreSQL 正式表。

## 目录结构

```
importer/
├── main.py             # CLI 入口（--dry-run 默认 / --commit 显式）
├── config.py           # 配置加载（.env）
├── database.py         # 数据库连接管理
├── models.py           # 数据模型（Sheet 读取结果、转换结果等）
├── excel_reader.py     # Excel 读取（openpyxl）
├── mapping_loader.py   # 从 meta 表动态加载映射（不硬编码）
├── validator.py        # 数据校验（表头、日期、数值、业务键）
├── transformer.py      # 数据转换（日期/百分比/ID 精度/空值）
├── repository.py       # 数据仓储（查询/删除/插入）
├── import_service.py   # 导入服务（事务 + replace_period 覆盖）
├── reconciliation.py   # 中文对账报告生成
├── logger.py           # 日志
├── requirements.txt    # 依赖
├── .env                # 数据库凭据（勿提交）
├── .env.example        # 配置模板
└── README.md
```

## 调用方式

```bash
# dry-run（默认，只校验不写入）
python main.py --file "Excel路径" --shop-id 1 --dry-run

# 正式导入（显式传入才允许写入）
python main.py --file "Excel路径" --shop-id 1 --commit
```

**默认 dry-run**：未传 `--commit` 时禁止任何正式数据写入/删除。

## 核心规则

- 11 张源工作表 → 9 张 core 正式表（成交概览/自营/合作合并进 douyin_deal_daily，以 sale_scope 区分）
- 字段映射以 `meta.field_mapping` 为唯一标准（418 条），不硬编码
- 百分比内部存 0–1 小数，展示 0.00%（3.78% → 0.0378）
- 日期兼容 Excel 原生 / 20260601 / 2026-06-01 / 2026/06/01
- ID 类字段按文本处理，防精度丢失
- SHA256 文件重复检测
- replace_period 覆盖：单事务内 先删旧（按工作表实际日期范围）再插新，失败整体回滚

## 安全

- 使用专用账号 `ecommerce_importer`（最小权限，非超级管理员）
- 凭据仅存于 `.env`，已 gitignore，不进入代码/日志/聊天
