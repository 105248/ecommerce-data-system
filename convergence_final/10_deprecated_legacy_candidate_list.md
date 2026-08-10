# 10｜废弃对象候选清单

> 数据库最终架构收口检查｜封版版 V1.0｜第十二阶段
> 检查日期：2026-08-08
> **本清单仅输出候选，任何 DROP 均需人工确认后分批执行（第十六阶段）。**

---

## 一、筛选方法

对每个候选对象执行 8 项依赖证明：

```
1. 无 core 依赖          （对象不引用 core 表）
2. 无 mart 依赖          （无 ACTIVE mart 对象依赖它）
3. 无 MCP 调用           （mcp_server/tools 不引用）
4. 无 importer 调用      （importer/ 不引用）
5. 无 V1.1 调用          （v1.1/ 正式脚本不引用）
6. 无 V1.3 调用          （v1.3/ 正式脚本不引用）
7. 无测试依赖            （qa/、tmp_work/ 测试不依赖）
8. 无未来 F0.5 HTTP 计划调用（不在 04 白名单）
```

**无法证明 8 项全无 → 标 REVIEW，禁止删除。**

---

## 二、候选清单

### 候选1：`mart.metric_rule_v14`（VIEW）

| 依赖项 | 证明 | 结果 |
|---|---|---|
| core 依赖 | 仅依赖 meta.metric_formula_rule | ✅ 无 core |
| mart 依赖 | 无 ACTIVE 对象依赖它（pg_depend 查询为空）| ✅ 无 |
| MCP 调用 | tools/*.py 无引用 | ✅ 无 |
| importer 调用 | importer/ 仅历史脚本 `fix_stage4.py` 引用 | ⚠️ 历史脚本 |
| V1.1 调用 | v1.1/ 无引用 | ✅ 无 |
| V1.3 调用 | v1.3/ 无引用 | ✅ 无 |
| 测试依赖 | qa/ 引用？— `qa/v11_v13_critical/s0_scan.py` 为对象扫描脚本（只读枚举，非运行依赖）| ⚠️ 弱依赖 |
| F0.5 计划 | 不在 04 白名单 | ✅ 无 |

**结论：REVIEW**（非 CANDIDATE_DELETE——qa 扫描脚本会枚举所有对象，删除不影响其功能，但存在历史脚本 `fix_stage4.py` 潜在引用，需人工确认后清理历史脚本再删除）。

### 候选2：`mart.format_percent_2`（FUNCTION）

| 依赖项 | 证明 | 结果 |
|---|---|---|
| core 依赖 | 纯格式化函数（无表引用）| ✅ 无 |
| mart 依赖 | 无 ACTIVE 对象依赖（pg_depend 空）| ✅ 无 |
| MCP 调用 | tools/*.py 无引用 | ✅ 无 |
| importer 调用 | 无 | ✅ 无 |
| V1.1 调用 | 无 | ✅ 无 |
| V1.3 调用 | 无 | ✅ 无 |
| 测试依赖 | `sql/10_percent_check.sql`（历史百分比校验脚本）引用 | ⚠️ 弱依赖 |
| F0.5 计划 | 不在 04 白名单 | ✅ 无 |

**结论：REVIEW**——保留为 INTERNAL 展示工具亦可，删除需先清理历史校验脚本。

### 候选3：空 schema `stg` / `public`

| 项 | 证明 |
|---|---|
| 对象数 | 0（无表/视图/函数）|
| 依赖 | 无任何对象 |
| 建议 | **保留**（stg 为文档约定的暂存层占位；public 为 PG 默认）。仅文档标注为空，不删除。|

---

## 三、不构成候选的对象（已排除）

| 对象 | 排除原因 |
|---|---|
| audit.ai_diagnosis_run | AI 层审计写入（V1.1 Stage6 定义，system_prompt 明确未来写入）→ ACTIVE |
| _diag_*（8 个内部函数） | get_diagnostic_snapshot 内部调用链 → INTERNAL |
| assert_period / assert_rank_args | 内部校验，被所有排名/汇总函数调用 → INTERNAL |
| resolve_scope / period_scope_rule / scope_daily | Scope Resolver 三层架构 → INTERNAL |
| previous_period / resolve_diagnostic_period | 环比/诊断周期统一窗口 → INTERNAL |
| detect_anomalies 等写库函数 | V1.1 批处理入口（MCP 之外）→ ACTIVE |
| 全部 SEQUENCE | 表附属基础设施 → INTERNAL |
| get_master_product_period_summary 等 | V1.3 正式功能（MCP 间接调用链）→ ACTIVE |

---

## 四、汇总

| 候选 | 类型 | 状态 | 处置 |
|---|---|---|---|
| mart.metric_rule_v14 | VIEW | REVIEW | 人工确认后：清理历史脚本 → 标 LEGACY → 可删 |
| mart.format_percent_2 | FUNCTION | REVIEW | 人工确认后：清理历史脚本 → 标 LEGACY → 可删 |
| stg / public | SCHEMA | 保留 | 不删（占位）|

**当前 0 个 CANDIDATE_DELETE 对象可直接删除。全部为 REVIEW，等待人工确认。**


---

## P2 清零补充（2026-08-08 18:29:25）

## P2 清零更新：REVIEW 对象生命周期已明确

| 对象 | 类型 | 生命周期状态 | 规则 |
|---|---|---|---|
| mart.metric_rule_v14 | VIEW | **LEGACY-REVIEW（可 CANDIDATE_DELETE）** | 8 项依赖全 0（MCP=0 / Importer 正式运行=0 / V1.1=0 / V1.3=0 / F0.5 白名单=0 / 正式测试=0 / 函数引用=0 / 视图引用=0）；仅历史脚本 importer/fix_stage4.py 弱依赖 |
| mart.format_percent_2 | FUNCTION | **LEGACY-REVIEW（可 CANDIDATE_DELETE）** | 同上，仅历史脚本弱依赖 |

- **非 ACTIVE 公共接口**：F0.5 不允许调用；新代码不得新增依赖。
- **本轮不自动 DROP**（需人工批准后执行）；P2 已关闭（生命周期与禁依赖规则明确，REVIEW 存在≠P2）。
