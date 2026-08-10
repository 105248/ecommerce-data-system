# 02｜重复对象与重复计算检查报告

> 数据库最终架构收口检查｜封版版 V1.0｜第四~五阶段
> 检查日期：2026-08-08｜数据库：ecommerce_db（PostgreSQL 16.6）

---

## 一、检查范围与方法

- 同一指标多套 Function（含同名多签名版本链）
- 同一查询多个近似 View
- 旧版/新版 Function 并存
- mart / MCP / Python 重复计算
- 同一指标分母不一致
- 同一比例不同加权方法
- 同一周期不同时间语义
- 页面专属计算写入数据库

方法：读取 `pg_proc` 全部函数源码 + `pg_get_viewdef` 全部视图定义 + MCP `tools/*.py` 全量静态扫描 + importer / ai_layer 扫描，逐项比对关键指标公式。

---

## 二、总体结论

**不存在重复业务口径。** 关键指标公式（退款率、投放费比、综合费比、环比窗口）在全部相关函数中分母/分子一致；MCP、AI、importer 均未建立第二套经营公式。唯一"近似对象"是中文数据查看层（40 个中文 View），属于设计内的人工查看层，非重复计算。

---

## 三、逐项检查结果

### 3.1 同一指标多套 Function —— ✅ 无重复

| 指标 | 唯一实现 | 说明 |
|---|---|---|
| 店铺经营汇总 | `get_business_period_summary` | 单店/Scope 口径 |
| 平台经营汇总 | `get_platform_business_period_summary` | 跨店（V1.3）|
| 投放汇总 | `get_advertising_period_summary` | V1.0.1 投放 10 项指标 |
| 环比（经营） | `compare_business_period` | 固定 N 天 vs 紧邻前 N 天 |
| 环比（投放） | `compare_advertising_period` | 同上，投放口径 |
| 环比（平台） | `compare_platform_business` | V1.3 平台跨店 |
| 诊断快照 | `get_diagnostic_snapshot` + `_diag_*`（内部） | 6+ 域统一入口 |
| 异常检测 | `detect_anomalies`（写库批处理）+ `get_anomalies/get_anomaly_summary/get_entity_anomalies`（查询） | 职责分离 |
| 机会检测 | `detect_growth_opportunities`（写库）+ `get_growth_opportunities/get_entity_opportunity/get_opportunity_summary`（查询） | 职责分离 |
| 诊断 | `diagnose_entity` / `diagnose_anomaly` + `get_diagnostic_result/get_entity_diagnosis` | 职责分离 |
| 行动项 | `generate_daily_action_items`（写库）+ `get_daily_action_list` | 职责分离 |
| 排名 | `rank_accounts/audiences/carriers/categories/master_products/price_bands/products` | 每域一函数 |
| 贡献度 | `get_business/account/category/product/shop_contribution` | 每域一函数 |
| Coverage | `get_data_coverage`（店铺）+ 平台函数内 coverage | 单一实现 |
| 变化拆解 | `decompose_platform_change_by_shop` / `decompose_master_product_by_shop_product` | 各一函数 |

**版本链检查**：`GROUP BY proname HAVING count(*)>1` → **0 个同名多签名函数**，不存在旧版/新版 Function 并存。

### 3.2 同一查询多个近似 View —— ⚠️ 结构合理，无重复计算

mart 共 18 个 View，分三类：

| 类别 | View | 性质 |
|---|---|---|
| core 直通/列映射（9） | account/audience/carrier/category/content/price_band/product/shop/terminal _daily | 列名映射 + shop 关联，**无计算** |
| 平台层（1） | douyin_platform_daily | 跨店 SUM（仅可加字段），单平台单实现 |
| 规则/元数据（8） | analysis_metric_whitelist / stage3_expected_scope_map / metric_rule_v14 / product_mapping_conflicts / product_master_resolution / sku_mapping_conflicts / sku_master_resolution / unmapped_products | 主数据/规则视图 |

中文数据 schema 40 个 View 是 mart/core/meta/audit 的**中文包装层**（`refresh_chinese_views` 维护），与 mart View 一一对应，属"人工查看层"设计，不计入重复计算。

**唯一注意项**：`mart.metric_rule_v14` = `meta.metric_formula_rule` 按 `mapping_version IN ('V1.4','V1.0.1')` 过滤的视图。无任何正式调用方（MCP 不引用，importer 仅历史脚本 `fix_stage4.py`/`gen_v14*.py` 使用）。→ 建议 **REVIEW**（见 3.7）。

### 3.3 mart / MCP / Python 重复计算 —— ✅ 无

| 层 | 检查结果 |
|---|---|
| MCP tools/*.py | 54 个工具全部经 `SELECT * FROM mart.func(...)` 消费，**无一处 Python 重算指标**（无 NULLIF/SUM/除法逻辑） |
| AI 层 ai_layer/ | 纯文本模板（system_prompt/metric_aliases/routing_rules），**无任何数值计算** |
| importer | 纯数据摄取（Excel→core），**无经营指标重算**；probe_formulas.py / verify_settle.py 为历史公式探测脚本，非运行路径 |
| 报告模板 | report_templates/v1.0 直接调 `get_business_report` 等，无二次计算 |

### 3.4 同一指标分母不一致 —— ✅ 一致

| 指标 | 公式（全部函数一致） | 验证函数 |
|---|---|---|
| 退款率 | `SUM(refund_amount_pay_time)/NULLIF(SUM(user_pay_amount),0)` | get_carrier/content/product/terminal/account/category/business_period_summary 共 8 处一致 |
| 投放费比（剔除退款、店铺绑定） | `SUM(ad_spend_shop_bound)/NULLIF(SUM(settlement_amount),0)` | 上述 5 处 + get_advertising_period_summary 一致 |
| 投放费比（V1.4 修正） | 分母 = `settlement_amount`（不是 net_transaction_amount） | get_business_report 注释确认 |
| 综合费比/效率 | 加权源比率，**禁止 AVG** | get_advertising_period_summary 注释明确 |

### 3.5 同一周期不同时间语义 —— ✅ 一致

- 环比窗口统一：`previous_period`（本期 N 天 vs 紧邻前 N 天，previous_end = current_start - 1）
- 所有 compare_* 函数共用此语义；`resolve_diagnostic_period` 为 V1.1 等长前置对比（同规则）
- Coverage "最近 N 天" 以数据库 `max_date`（2026-06-30）为终点，全系统一致

### 3.6 页面专属计算写入数据库 —— ✅ 无

- 未发现"页面布局/排序/¥%/收藏/导航/导出样式"相关表或函数
- `format_percent_2` 仅为**展示格式化**（注释明确"仅用于展示，不用于后续数学计算"），且不被 MCP 调用——建议 REVIEW（见 3.7）

### 3.7 建议 REVIEW 对象汇总

| 对象 | 类型 | 当前调用方 | 差异 | 风险 | 建议状态 |
|---|---|---|---|---|---|
| mart.metric_rule_v14 | VIEW | 无正式调用（仅历史脚本 fix_stage4/gen_v14） | meta.metric_formula_rule 的版本过滤 | 低：不参与经营计算，但游离于正式接口外 | REVIEW → 若确认无调用方可 LEGACY |
| mart.format_percent_2 | FUNCTION | 无（MCP 未调用） | 展示格式化工具 | 低 | REVIEW → INTERNAL 或 LEGACY |
| 中文数据 40 View | VIEW | 人工查看层 | 中文包装 | 无 | ACTIVE（设计内） |
| stg / public schema | SCHEMA | 空 schema（0 对象） | 无 | 低 | 保留（预留）或归档 |

---

## 四、问题等级结论

| 等级 | 数量 | 说明 |
|---|---|---|
| P0（正式指标冲突） | 0 | 公式全一致 |
| P1（多 ACTIVE 实现同一能力） | 0 | 每能力唯一实现；检测/查询职责分离 |
| P2（旧 View、命名、文档） | 2 | metric_rule_v14 游离、format_percent_2 未被正式调用（均为低影响，不阻断封版） |

---

*本报告仅分析，未执行任何 DROP/ALTER。*
