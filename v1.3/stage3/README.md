# V1.3 Stage3｜跨店商品 / SKU / 品线主数据 — README

> 阶段性质：V1.3 公司级商品主数据基础层。建立 Master Product / Master SKU / Product Line 主数据体系，解决"同一真实商品在不同店铺不同 ID/名称"问题。
> **本阶段只做主数据、映射、归属、冲突治理和查询能力；不做天猫/京东接入、不重算经营指标、不修改现有抖音单店/多店经营口径。**
> 本阶段通过后停止，等待确认进入 V1.3 阶段4《天猫数据接入》。

## 一、交付文件

| 文件 | 说明 |
|---|---|
| `01_masterdata_tables.sql` | 7 张主数据表 + 审计日志 + 初始品线（鱼子酱/人参） |
| `02_masterdata_functions.sql` | code 生成/审计触发器 + 时间重叠冲突检测 + resolve_master_product + get_master_product_members + get_product_line_members |
| `03_masterdata_views.sql` | 解析 View / SKU 解析（SKU_SOURCE_NOT_AVAILABLE）/ 未映射商品 / 冲突 View |
| `04_masterdata_summary.sql` | 跨店 Master Product 汇总（仅 CONFIRMED）/ 品线汇总 / rank_master_products / 质量指标 |
| `05_masterdata_security.sql` | ecommerce_masterdata_admin 角色 + agent_readonly 只读 |
| `06_masterdata_cn_layer.sql` | 中文数据层 9 View |
| `07_masterdata_initial.sql` | 初始治理（第一批 34 MP / 39 映射，跨店同款归组） |
| `08_masterdata_supplement.sql` | 补充治理（GMV≥10000 全部确认，77 MP / 82 映射） |
| `qa\v1.3_stage3_test_results.md` / `bug_log.csv` | 测试结果 / 问题记录 |

## 二、主数据层级

```
公司 → 品线(product_line) → Master Product → Master SKU
                                        ↓
                      Platform Product Mapping（platform+shop+platform_product_id）
                      Platform SKU Mapping（SKU 源接入后启用）
```

## 三、核心对象

| 表/函数 | 说明 |
|---|---|
| `meta.product_line` | 品线（YIZIJIANG 鱼子酱 / RENSHEN 人参） |
| `meta.master_product` | 公司商品主档（MP000001 编码自动生成） |
| `meta.master_sku` | 公司 SKU 主档（MS000001；框架预留，当前抖音源无 SKU） |
| `meta.platform_product_mapping` | 平台商品映射（跨店按 shop_id 隔离；valid_from/to 有效期） |
| `meta.master_product_alias / master_sku_alias` | 别名表（候选匹配用） |
| `audit.masterdata_change_log` | 变更审计（历史可追溯，禁物理删除历史映射） |
| `mart.resolve_master_product(...)` | 查商品归属（业务日期解析） |
| `mart.get_master_product_members(...)` | 跨店成员 |
| `mart.get_product_line_members(...)` | 品线成员 |
| `mart.get_master_product_period_summary(...)` | 跨店汇总（仅 CONFIRMED + mapping coverage） |
| `mart.get_product_line_period_summary(...)` | 品线汇总（expected/mapped/unmapped + 店铺覆盖） |
| `mart.rank_master_products(...)` | Master Product 跨店排名（与店铺内 rank_products 并存） |
| `mart.get_masterdata_quality(...)` | 质量指标（GMV/数量覆盖率、品线归属率、冲突数、高价值未映射数） |
| `中文数据.公司商品主档 / 公司SKU主档 / 品线配置 / 平台商品映射 / 平台SKU映射 / 未归属商品 / 未归属SKU / 商品映射冲突 / SKU映射冲突` | 中文层 9 View |

## 四、关键规则（勿改）

1. **状态机**：CONFIRMED（唯一可入正式汇总）/ SUGGESTED / UNMAPPED / CONFLICT / DISABLED；来源 MANUAL/EXACT_ID_RULE/EXACT_NAME_SUGGESTION/ALIAS_SUGGESTION/AI_SUGGESTION/IMPORT_FILE。
2. **唯一身份**：platform_code + shop_id + platform_product_id（SKU 再加 platform_sku_id）；禁止仅按平台商品 ID 全平台唯一。
3. **有效期**：valid_from/valid_to；时间重叠 → CONFLICT（`check_mapping_period_conflict` 检测，不静默覆盖）；历史映射不物理删除（enabled=false / valid_to 关闭）。
4. **SKU 优先**：当前抖音源无 SKU 维度 → `SKU_SOURCE_NOT_AVAILABLE`（不伪造平台 SKU）；真实 SKU 源接入后启用 SKU 映射优先规则。
5. **名称不自动确认**：完全同名/标准化同名仅生成候选（SUGGESTED）；CONFIRMED 必须人工确认（reviewed_by）。
6. **未归属允许存在**：product_line_id=NULL，不建"其他/未分类"自动品线。
7. **跨店汇总仅 CONFIRMED 成员**；未确认候选不得并入；返回 mapped_shop_count/unmapped_member_count/mapping_complete。
8. **core 不改写**：core 保持平台原始身份；主数据在 mart 解析层映射（映射纠正无需重写经营事实）。

## 五、权限

- `agent_readonly`：主数据只读（读 PASS / 写 DENIED，read-only 事务拦截验证）。
- `ecommerce_masterdata_admin`（新角色）：meta 主数据 CRUD + 审计日志写入；core 仅 SELECT（写 core 拒绝验证）。

## 六、验收摘要

- ✅ **34/34 测试 PASS**（跨店同款 / 映射冲突检测 / 历史有效期 resolve / 品线继承 / SKU 源不可用 / 跨店汇总 20 MP=成员 SUM / 未映射不并入 / 新增品线/MP 无需代码）
- ✅ 封版门槛：GMV 覆盖率 95.82%、TOP20 商品 100% 确认、重点品线（鱼子酱/人参）确认、冲突 0、**高价值未映射 0**
- ✅ 性能：resolve 1.2ms / members 0.4ms / line 0.7ms / summary 0.5ms（目标 <1s/<2s）
- ✅ 初始治理：77 个 Master Product / 82 条 CONFIRMED 映射 / 3 个跨店同款 / 品线归属鱼子酱 18 + 人参 5
- ✅ 安全：agent_readonly 只读、masterdata_admin CRUD（写 core 拒绝）
- ✅ 旧系统回归：官方 9,397,490.90 / 平台汇总 12,479,980.53 / core 4320 行不变
- ✅ P0=0 P1=0 P2=0

## 七、MCP 新增 7 工具（33→40）

`list_master_products` / `get_master_product_members` / `resolve_master_product` / `list_product_lines` / `get_product_line_members` / `get_unmapped_products` / `get_mapping_conflicts`（`mcp_server/tools/masterdata_tools.py`）。

## 八、AI

system_prompt「商品主数据（V1.3 Stage3）」节：工具路由 + **AI 只给候选判断不自动确认**（agent_readonly 只读，不修改主数据）。
