# 11｜完整依赖风险报告

> 数据库最终架构收口检查｜封版版 V1.0｜第十三阶段
> 检查日期：2026-08-08

---

## 一、检查项全景

| 检查项 | 结论 |
|---|---|
| ACTIVE → LEGACY | ✅ 0（当前无 LEGACY 对象）|
| ACTIVE → DEPRECATED | ✅ 0（当前无 DEPRECATED 对象）|
| MCP → LEGACY | ✅ 0（MCP 引用的 51 个对象全部 ACTIVE）|
| Function → 旧 View | ⚠️ 2 个历史脚本引用 metric_rule_v14（非正式函数）|
| Function 版本链 | ✅ 0（无同名多签名函数）|
| 重复安全包装 | ✅ 0（无重复包装层）|
| 测试 → 旧对象 | ⚠️ qa/s0_scan.py 枚举全部对象（只读，无破坏性）|
| Importer → 旧对象 | ⚠️ importer/fix_stage4.py 引用 metric_rule_v14（历史修复脚本）|

---

## 二、风险明细

### 2.1 历史脚本引用游离对象（P2）

| 引用方 | 被引用对象 | 性质 | 风险 |
|---|---|---|---|
| `importer/fix_stage4.py` | mart.metric_rule_v14 | 一次性历史修复脚本 | 若未来再运行且视图已删 → 脚本报错；但该脚本已被 V1.0.1 公式修复取代 |
| `sql/10_percent_check.sql` | mart.format_percent_2 | 历史百分比校验脚本 | 同上 |
| `qa/v11_v13_critical/s0_scan.py` | 全部数据库对象 | 对象扫描（枚举清单比对）| 只读枚举，删除任何对象都只影响比对基线，无运行破坏 |

**处置建议**：metric_rule_v14 与 format_percent_2 已列入 10 报告 REVIEW；人工确认后先归档/删除历史脚本，再评估对象去留。**不影响当前运行链路。**

### 2.2 依赖链完整性验证（无风险）

```
MCP(54) ──> 51 个 ACTIVE 对象 ──> core 9 表（经 SECURITY DEFINER 函数）
                                    meta 13 表
                                    audit 3 表
```

- **视图链**：mart.*_daily → core.douyin_*_daily（单向，无环）
- **中文数据 40 View** → mart 18 View / core / meta / audit（单向，refresh_chinese_views 按字典重建）
- **函数链**：get_diagnostic_snapshot → _diag_*（内部）；diagnose_anomaly → diagnose_entity → get_diagnostic_snapshot；detect_anomalies → get_diagnostic_snapshot（均为单向）
- **无循环依赖**（pg_depend 全量扫描确认）

### 2.3 安全包装层（无重复）

- 唯一安全包装模式：`SECURITY DEFINER` 函数（68 个，全部固定 search_path）→ agent_readonly 经 EXECUTE 访问
- 无"重复安全包装"（如函数外再包函数、多层 SUID）

---

## 三、依赖风险等级

| 等级 | 数量 | 说明 |
|---|---|---|
| P0 | 0 | 无 ACTIVE→LEGACY、无 MCP 绕过 |
| P1 | 0 | 无正式链路依赖旧对象 |
| P2 | 2 项 | 历史脚本引用 metric_rule_v14 / format_percent_2（低风险，不阻断）|

---

## 四、结论

**依赖链健康。** 无 ACTIVE 依赖 LEGACY/DEPRECATED；MCP 依赖全部收敛至 ACTIVE；唯一风险点为 2 个历史脚本对游离对象的弱引用（P2，列入废弃候选 REVIEW）。

---

*本报告仅分析，未执行任何 DROP/ALTER。*


---

## P2 清零补充（2026-08-08 18:29:25）

## 数字口径修正（P2 清零）

- **MCP 工具数：54**（server.TOOLS 实测注册）。
- **MCP 依赖唯一数据库对象：56**（mart 50 = 47 函数 + 3 视图 analysis_metric_whitelist/product_mapping_conflicts/unmapped_products；meta 5 = shop/platform/master_product/platform_product_mapping/product_line；audit 1 = import_batch；**core 0 直读**）。
- 白名单接口 54（设计口径）≠ MCP 代码依赖 56 对象（实现口径），概念已区分，数字不再混淆。
