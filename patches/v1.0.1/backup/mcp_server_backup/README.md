# mart V1.0 Stage4｜MCP 只读数据服务

把已验收的 mart 能力以 stdio MCP 形式安全提供给 AI 客户端。

## 架构

```
AI Client (WorkBuddy/OpenClaw)
   ↓ stdio
MCP Server (server.py)
   ↓ 参数校验 / 限制行数 / 结构化返回
agent_readonly (只读数据库角色, default_transaction_read_only=on)
   ↓
已验收 mart Function (Stage2 Period / Stage3 Compare·Rank·Contribution)
```

## 目录

```
mcp_server/
  server.py          # MCP stdio 入口，注册 18 个工具
  config.py          # .env 读取 / 参数常量
  database.py        # 只读连接 / 查询（仅 SELECT）
  schemas.py         # 参数校验 / 统一 JSON 返回
  tools/             # 按业务域拆分
    catalog_tools.py   # list_shops / get_data_coverage / get_metric_catalog / get_import_history / health_check
    business_tools.py  # get_business_summary / compare_business
    product_tools.py   # get_product_summary / rank_products / get_product_contribution
    account_tools.py   # get_account_summary / rank_accounts / get_account_contribution
    category_tools.py  # get_category_summary / rank_categories / get_category_contribution
    domain_tools.py    # carrier/content/terminal/price_band/audience summary + rank_carriers/rank_price_bands/rank_audiences
  .env               # 数据库连接（密码仅存此处，不入库）
  requirements.txt
```

## 运行

```bash
# 使用项目 venv python
C:/Users/EDY/.workbuddy/binaries/python/envs/default/Scripts/python.exe server.py
```

## 设计边界（禁止）

- 不提供任意 SQL 工具（execute_sql/raw_sql/query_sql）
- 不自算比例/均值（一律由 mart Function 按 V1.4 加权返回）
- 不用商品明细重建商品 TOTAL、不用 account 明细重建全店 TOTAL
- 不返回 shop_id 作为主字段，对外统一 shop_name
- 不写经营建议（那是 Stage5 的职责）
- NULL 保持 NULL（不转 0 / "0%" / "无变化"）
