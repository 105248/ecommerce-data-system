# 05｜MCP 依赖检查报告

> 数据库最终架构收口检查｜封版版 V1.0｜第七阶段
> 检查日期：2026-08-08｜MCP Server：`mcp_server/`（SDK 1.29.0，注册工具 54 个）

---

## 一、检查结论（概要）

| 检查项 | 结论 |
|---|---|
| MCP 是否调用 LEGACY | ✅ 否 |
| MCP 是否调用 DEPRECATED | ✅ 否 |
| MCP 是否绕过正式 mart | ✅ 否（仅 4 处读 meta/audit 主数据，符合白名单）|
| 是否存在 unrestricted SQL | ✅ 否（全部参数化 `%s`）|
| MCP helper 是否重算经营指标 | ✅ 否（纯消费，无公式）|

---

## 二、MCP → 数据库依赖全景

MCP 54 个工具共依赖 **56 个数据库对象**（mart 50=47函数+3视图 / meta 5 / audit 1；core 0 直读），全部为白名单内 ACTIVE 对象：

- **mart 函数**：46 个（`get_*` / `rank_*` / `compare_*` / `decompose_*` / `resolve_*`）
- **mart 视图**：3 个（`analysis_metric_whitelist`、`product_mapping_conflicts`、`unmapped_products`）
- **meta 表/视图**：4 个（`shop`、`platform`、`master_product`、`platform_product_mapping`、`product_line`——只读主数据查询）
- **audit 表**：1 个（`import_batch`——导入历史查询）

**依赖关系**：MCP whitelist → 数据库 Function → mart（核心计算全部下沉数据库，MCP 只做参数校验与结果序列化）。

---

## 三、逐项验证明细

### 3.1 不调用 LEGACY / DEPRECATED ✅

- 生命周期盘点结果：当前数据库 **0 个 LEGACY / 0 个 DEPRECATED / 0 个 REVIEW**（详见 01 盘点 CSV）
- MCP 引用的 56 个对象 100% 属于 ACTIVE
- 历史遗留对象 `metric_rule_v14`、`format_percent_2` 未被 MCP 引用（已在 02 报告标注 REVIEW）

### 3.2 不绕过正式 mart ✅

- **0 处** `FROM core.*` 直接查询（core 对 agent_readonly 无 SELECT 授权，物理阻断）
- 4 处 meta 查询均为主数据只读（店铺/平台/主档/映射），符合"正式接口白名单"中 MASTER_DATA 类目
- 1 处 audit 查询（`get_import_history` → `audit.import_batch`）为导入历史目录，符合白名单

### 3.3 无 unrestricted SQL ✅

- 全部 54 工具使用 `database.query(sql, params)` 参数化调用（`%s` 占位符 + 类型显式转换如 `%s::date`）
- 无 `f-string` SQL 拼接、无 `format()` 动态拼 SQL、无 `exec/eval`、无 `execute_values` 不受控入口
- 唯一参数化例外：`rank_*` 系列将 `sort_by` 白名单校验（`analysis_metric_whitelist`）后才传入，字段名不可注入

### 3.4 helper 不重算经营指标 ✅

- 54 工具全部为"SELECT * FROM mart.func(...) → 字段透传 + JSON 序列化"
- 未发现 `SUM/NULLIF/AVG/除法` 等经营计算逻辑（2026-08-08 全量静态扫描）
- 唯一格式化辅助 `_fmt_ratio` 仅做百分比展示（如 `0.1972 → 19.72%`），不参与后续计算

---

## 四、边界说明

1. **后台写库函数不在 MCP 白名单**：`detect_anomalies` / `detect_growth_opportunities` / `diagnose_anomaly` / `diagnose_entity` / `generate_daily_action_items` 为批处理/触发入口（写 mart 事件表），由 V1.1 调度或人工触发，**不通过 MCP 暴露**——符合"MCP 只读"安全模型。
2. **meta 函数**（`audit_mapping`/`refresh_chinese_views` 等）为触发器/维护内部调用，不属公共接口。
3. 未来 Backend API 应沿用同样约束：**只消费白名单，不直查 core，不重算指标**。

---

## 五、结论

**MCP 依赖检查 PASS。** MCP 层对数据库的依赖完全收敛到正式 mart/主数据白名单，无 LEGACY 调用、无绕过、无动态 SQL、无重复计算。

---

*本报告仅分析，未执行任何 DROP/ALTER。*
