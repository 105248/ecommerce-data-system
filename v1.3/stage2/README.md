# V1.3 Stage2｜抖音多店统一经营层 — README

> 阶段性质：V1.3 抖音多店聚合经营层。建立"抖音平台整体"经营视角：单店 / 多店汇总、店铺贡献、跨店变化拆解，完整接入 mart / MCP / AI。
> **本阶段只做抖音多店统一经营；不做跨店商品主数据统一、不做天猫/京东、不做跨平台。**
> 本阶段通过后停止，等待确认进入 V1.3 阶段3《跨店商品 / SKU / 品线主数据》。

## 一、交付文件

| 文件 | 说明 |
|---|---|
| `01_platform_meta.sql` | meta.platform 平台维度 + 平台→店铺关系 |
| `02_platform_business_summary.sql` | `get_platform_business_period_summary`（平台汇总+coverage）+ `compare_platform_business`（环比） |
| `03_shop_contribution.sql` | `get_shop_contribution`（店铺贡献）+ `decompose_platform_change_by_shop`（变化拆解） |
| `04_platform_daily_and_diagnostic.sql` | `mart.douyin_platform_daily`（平台日表）+ `get_platform_diagnostic_snapshot`（平台快照） |
| `05_platform_mcp_security.sql` | 5 平台函数权限（SECURITY DEFINER + PUBLIC 无 + agent_readonly） |
| `06_platform_cn_layer.sql` | 中文 View：抖音多店经营日报 / 抖音店铺贡献 / 抖音多店数据覆盖 |
| `douyin_multishop_metric_rules.md` | 平台指标规则（可加/比例重算/非AVG证明/Scope/商品限制） |
| `douyin_multishop_coverage_rules.md` | coverage 规则与 4 场景验证 |
| `douyin_multishop_ai_rules.md` | AI 平台语义规则 |
| `qa\v1.3_stage2_test_results.md` / `bug_log.csv` | 测试结果 / 问题记录 |

## 二、数据库对象

| 对象 | 类型 | 说明 |
|---|---|---|
| `meta.platform` | 表 | 平台维度（douyin/抖音/enabled） |
| `mart.get_platform_business_period_summary(text,date,date,text)` | 函数 | 平台整体汇总（40+ 列含 coverage 8 字段） |
| `mart.compare_platform_business(text,date,date,text,text)` | 函数 | 平台环比 |
| `mart.get_shop_contribution(text,date,date,text,text)` | 函数 | 店铺贡献（本期/上期/变化） |
| `mart.decompose_platform_change_by_shop(text,date,date,text,text)` | 函数 | 平台变化拆解（net/gross_neg/gross_pos/neg_share） |
| `mart.douyin_platform_daily` | View | 平台日表（platform×date） |
| `mart.get_platform_diagnostic_snapshot(text,date,date,text)` | 函数 | 平台整体诊断快照（18 指标+coverage） |
| 中文数据.抖音多店经营日报 / 抖音店铺贡献 / 抖音多店数据覆盖 | View | 中文层 |

全部 SECURITY DEFINER + 固定 search_path + PUBLIC 无 EXECUTE + agent_readonly 批准执行。

## 三、关键口径（勿改）

1. **范围**：`enabled=true AND platform_code='douyin'`；平台整体只在 mart 语义，无 shop_id=0。
2. **coverage**：enabled/covered/missing/complete + 日期按店检查（店存在且每店天数完整）。
3. **可加**：金额/计数 SUM；**成交人数=各店之和（跨店不去重）**。
4. **比例**：分子/分母重算；综合费比/效率=加权源比率；**禁止 AVG 两店比例**（323 项测试证明平台≠AVG）。
5. **拆解**：negative_impact_share = 单店负向绝对值/全部负向绝对值（不除以净额）。
6. **商品**：禁止按 product_name 跨店合并（Stage3 才做 master_product）。

## 四、MCP 新增 4 工具

`get_platform_business_summary` / `compare_platform_business` / `get_shop_contribution` / `decompose_platform_change_by_shop`（`mcp_server/tools/platform_tools.py`，工具总数 29→33）。MCP 只调 mart，不自算两店聚合（文档四十节）。

## 五、验收摘要

- ✅ **323/323 测试 PASS**（100+ 项两店 SUM 对账 / 比例非 AVG 6 案例 / coverage 4 场景 / 贡献度和=100% / 拆解关系 / 周期 / 性能）
- ✅ 性能：平台汇总 1.1ms、店铺贡献 0.8ms、拆解 0.7ms（目标 <3s/<5s）
- ✅ 单店回归：官方 9,397,490.90 / 个护 3,082,489.63 不变；平台汇总 12,479,980.53 = 两店之和
- ✅ 安全：5 平台函数 SECURITY DEFINER + agent_readonly
- ✅ AI：system_prompt 平台语义（coverage 表达义务 / 店铺对比 / 多轮切换 / 商品不合并）
- ✅ P0=0 P1=0 P2=0

## 六、与 V1.1 后续阶段的关系（说明）

文档第 29~34 节"平台级异常/诊断/机会/优先级/行动清单"依赖 V1.1 Stage2~6（异常检测引擎等）——这些阶段尚未实施（2.0 目录有任务文件待执行）。本阶段已提供**平台汇总 + 平台诊断快照**基础（`get_platform_diagnostic_snapshot` 返回"抖音整体"对象 + coverage），V1.1 Stage2~6 完成后按 `domain=platform / shop_name=NULL` 语义接入，不虚构实现。
