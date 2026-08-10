# 07｜权限最终收口报告

> 数据库最终架构收口检查｜封版版 V1.0｜第九阶段
> 检查日期：2026-08-08｜数据库：ecommerce_db（PostgreSQL 16.6）

---

## 一、检查结论（概要）

| 检查项 | 结论 |
|---|---|
| agent_readonly 不可写 | ✅ 零写权限（INSERT/UPDATE/DELETE/TRUNCATE 均为空）|
| agent_readonly 不可任意查 core | ✅ core 0 表可读（物理隔离）|
| 正式 Function 白名单可执行 | ✅ agent_readonly 对 57 个 mart 函数有 EXECUTE |
| PUBLIC 无不必要权限 | ⚠️ 10 个函数仍 PUBLIC EXECUTE（待 REVOKE，见遗留）|
| 未来 Backend reader 可沿用最小权限 | ✅ 同一 agent_readonly 模型可直接复用 |

---

## 二、角色与权限现状

### 2.1 角色清单

| 角色 | superuser | login | 用途 |
|---|---|---|---|
| postgres | ✅ | ✅ | 超级管理员（DDL/备份/恢复）|
| agent_readonly | ❌ | ✅ | MCP / 未来 Backend 只读 |
| ecommerce_importer | ❌ | ✅ | 导入写 core |
| ecommerce_masterdata_admin | ❌ | ❌ | 主数据维护（无登录）|

### 2.2 agent_readonly 权限明细

- **Schema USAGE**：mart / meta / audit（无 core、无 stg、无 中文数据）
- **表 SELECT**：25 个（mart 16 + meta 8 + audit 1），**core 0 个**
- **函数 EXECUTE**：57 个（全部 mart 正式函数）
- **写权限**：**0**（INSERT/UPDATE/DELETE/TRUNCATE 全空）
- **DDL**：无 CREATE on schema

> 注：agent_readonly 可读 `audit.masterdata_change_log`（主数据审计日志）与 `meta` 全部主数据表，属最小白名单的合理扩展；若 F0.5 需要更严格口径可再收敛，**当前不构成 P0/P1**。

### 2.3 检查异常项

#### ⚠️ 遗留1：10 个函数 PUBLIC EXECUTE（P2）

以下函数仍对 PUBLIC 授予 EXECUTE（默认授权未撤销）：

| Schema | 函数 | 性质 |
|---|---|---|
| mart | get_business_report | **正式接口**（应在白名单内仅 agent_readonly 可执行）|
| mart | _diag_master_product | 内部诊断（应仅 SECURITY DEFINER 链内调用）|
| mart | _diag_product_line | 内部诊断 |
| mart | check_mapping_period_conflict | 内部校验 |
| meta | audit_mapping / audit_masterdata | 触发器内部 |
| meta | gen_master_product_code / gen_master_sku_code | 触发器内部 |
| meta | check_chinese_coverage / refresh_chinese_views | 维护工具 |

**风险**：低。PUBLIC 仅 EXECUTE（无写能力），且这些函数多数是内部函数；`get_business_report` 为只读正式函数。但按"PUBLIC 没有不必要权限"原则应 REVOKE。
**建议**：与历史遗留"5 个 SECURITY DEFINER 函数 PUBLIC EXECUTE"一并处理——人工确认后执行 `REVOKE EXECUTE ON FUNCTION ... FROM PUBLIC`（本轮不执行，仅记录）。

#### ✅ 已收敛项

| 项 | 状态 |
|---|---|
| SECURITY DEFINER 函数 | 68 个全部固定 `search_path`（0 个未固定）|
| SECURITY DEFINER owner | 全部 postgres（无低权限 owner）|
| PUBLIC schema 权限 | core/meta/audit/mart/stg/中文数据 均无 PUBLIC CREATE/USAGE（仅 public schema 保留默认 USAGE）|
| PUBLIC 表权限 | 0（无 PUBLIC SELECT）|
| core 直读 | agent_readonly / PUBLIC 均不可读 |
| 角色成员 | 无业务角色继承链（仅 pg 内置）|

---

## 三、最小权限模型验证（F0.5 Backend 可复用）

**agent_readonly 权限模型**（2026-08-08 实测）即 F0.5 Backend reader 模板：

```
agent_readonly
├─ USAGE  : mart / meta / audit
├─ SELECT : 25 个白名单表/视图（不含 core）
├─ EXECUTE: 57 个 mart 正式函数
└─ 写     : 无
```

**验证**：以 agent_readonly 实际执行 3 个代表性查询（get_business_report / rank_products / get_diagnostic_snapshot）均成功（见阶段15 恢复验证复用）。

---

## 四、问题等级

| 等级 | 数量 | 说明 |
|---|---|---|
| P0（只读角色可写 / 串店 / PUBLIC 严重过权） | 0 | agent_readonly 零写、core 物理隔离 |
| P1（PUBLIC 明显过度授权） | 0 | PUBLIC 仅 10 函数 EXECUTE 且均只读 |
| P2（PUBLIC 不必要权限） | 1 项 | 10 函数 PUBLIC EXECUTE 待 REVOKE（含 1 正式接口）|

---

*本报告仅分析，未执行任何 REVOKE/ALTER。遗留项列入最终报告待人工确认。*


---

## P2 清零补充（2026-08-08 18:29:25）

| 项 | 结果 | 说明 |
|---|---|---|
| PUBLIC EXECUTE（全库业务函数） | **0** | 10 个不必要 PUBLIC EXECUTE 已全部 REVOKE（get_business_report/_diag_master_product/_diag_product_line/check_mapping_period_conflict + meta 触发器维护 6）；agent_readonly 精确权限保留 |
| agent_readonly 回归 | PASS | get_business_summary / get_business_report / get_diagnostic_snapshot(含_diag内部链) / get_platform_business_summary 4 项 PASS |
| core SELECT / 写 / DDL | 0 / 0 / 0 | 不变 |
| 备份真实 Secret | **0** | 见 12 报告 |

**P2 遗留①（PUBLIC EXECUTE 10 函数）已关闭。**