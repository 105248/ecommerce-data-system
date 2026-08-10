# 12｜备份清单（Backup Manifest）

> 数据库最终架构收口检查｜封版版 V1.0｜第十四阶段
> 备份时间：2026-08-08 17:59-18:00｜数据库：ecommerce_db（PostgreSQL 16.6）

---

## 一、备份目录

`D:\ecommerce-data-system\convergence_final\backup\`

## 二、备份文件清单

| # | 文件名 | 大小(bytes) | 时间 | MD5 checksum |
|---|---|---|---|---|
| 1 | ecommerce_db_full_20260808_175949.dump | 3,721,044 | 2026-08-08 17:59:50 | 1152deb8f8e30cf43f82ac797e6d8c81 |
| 2 | ecommerce_db_schema_only_20260808_175949.sql | 765,495 | 2026-08-08 17:59:59 | 23a18859fe4815abe7a9a2801410df9e |
| 3 | mcp_server_env_20260808_175949.env | 270 | 2026-08-08 18:00:08 | 56af6f967bb5cb4dcbb022deccfd4f1f |
| 4 | master_data_master_product_20260808_175949.csv | 17,608 | 2026-08-08 18:00:08 | b4a4a2da974cf3d9ff3d5107a1ea2316 |
| 5 | master_data_platform_product_mapping_20260808_175949.csv | 24,212 | 2026-08-08 18:00:09 | cb57a16ed5dad1514f1e634d416d760b |
| 6 | master_data_shop_20260808_175949.csv | 254 | 2026-08-08 18:00:09 | fa92b913997902d495726239cc7132cd |
| 7 | master_data_product_line_20260808_175949.csv | 334 | 2026-08-08 18:00:10 | 2dd9972e292f9c1709d90650ffe3bb69 |
| 8 | mcp_server_code.tar.gz | 75,390 | 2026-08-08 18:00:24 | 2ae291000d1f63a8f27fd48a2beb3818 |
| 9 | importer_code.tar.gz | 68,863 | 2026-08-08 18:00:25 | 4096c0c2f8694ade9796054d5dcf9d32 |
| 10 | v11_sql.tar.gz | 54,582 | 2026-08-08 18:00:25 | 3839c3b0e8e55dad60802e684ee6260f |
| 11 | v13_sql.tar.gz | 33,465 | 2026-08-08 18:00:25 | bde63f1a1ead8122bd386828f4b06e71 |
| 12 | qa_tests.tar.gz | 53,468 | 2026-08-08 18:00:26 | 905a74a51ab835cdd15fefe4b2f81642 |
| 13 | config_sql.tar.gz | 3,492,112 | 2026-08-08 18:00:26 | d161caaa3dc5c8c3f7685be61adb15f8 |

**合计 13 个文件，约 8.3 MB。**

## 三、备份内容说明

| 类别 | 文件 | 内容 |
|---|---|---|
| 完整数据库 Dump | #1 | pg_dump -F c（含数据、schema、角色、权限）|
| Schema-only Dump | #2 | pg_dump -F p -s（纯结构，供 diff/重建）|
| 关键配置 | #3 | mcp_server/.env（连接配置，含只读+管理密码）|
| Master Data | #4-7 | master_product(77)/platform_product_mapping(82)/shop(2)/product_line(2) CSV |
| MCP 代码 | #8 | mcp_server/ 全量（server.py + tools/ + schemas.py）|
| Importer 代码 | #9 | importer/ 全量 |
| SQL 版本 | #10-11 | v1.1/（诊断层 6 阶段）+ v1.3/（多店 3 阶段）|
| 测试报告 | #12 | qa/ 全量（stage6、v1.1、v1.3 验收）|
| 配置/SQL | #13 | sql/ config/ report_templates/ patches/ |

## 四、备份环境信息

| 项 | 值 |
|---|---|
| PostgreSQL 版本 | 16.6（EDB zip 版）|
| 数据库名 | ecommerce_db |
| 备份方式 | pg_dump（postgres 超级用户）|
| 备份时间点 | 2026-08-08 17:59（与 01 盘点同库同刻，快照一致）|
| 校验方式 | MD5（上表）|

## 五、结论

**备份完成（Backup PASS）**——13 个文件齐全，全库 dump + schema-only + 配置 + 代码 + Master Data 全部覆盖，checksum 已记录，可用于第十五阶段隔离恢复验证。


---

## P2 清零补充（2026-08-08 18:29:25）

## P2 清零更新：备份不含真实凭据

- `mcp_server_env_20260808_175949.env`（真实凭据）已从本备份目录**移出**至 `D:/ecommerce-data-system/.secrets_isolated/`（本机隔离区，不进普通备份包）。
- 3 个含 .env 的 tar.gz（config_sql / importer_code / mcp_server_code）已**重新打包排除 .env**。
- `.env.example` 模板凭据字段已规范为 `[REDACTED]` / 占位变量。
- **终扫：backup 目录真实密码=0 / Token=0 / Secret=0**。
- 该含密码备份从未离开本机、未上传、未共享 → 无需因此轮换密码。
- **正式备份约定**：`.env` 不进入任何普通备份包；仅保存脱敏配置模板 `.env.example`。
