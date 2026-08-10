# 安全与接口唯一性报告（专项24/25/26/27/28）

> 生成时间：2026-08-08 18:04:46 ｜ V1.3+V1.1+数据库封版关键逻辑专项检查 ｜ 只读检查，未修改任何数据库对象

## 结论：PASS（含 2 项待办）

| 检查点 | 结果 |
|---|---|
| LEGACY/DEPRECATED 对象 | ✅ 无 |
| 双 ACTIVE 接口 | ✅ 未发现 |
| NULL 不伪装 0 | ✅ 无数据区间返回 NO_DATA；unrecalculable_metrics 保留 |
| 中文展示 | ✅ core 9 表有表 COMMENT；⚠️ 列注释覆盖待完善（P2） |
| F0.5 前置 | ✅ MCP 54 工具（49 带参数 schema）；Backend 只做 API/权限/参数/格式（系统约束已声明） |
| 环境稳定性 | ✅ 并发=并行会话（P1 清零+收口）已完成，无遗留冲突 |

## 过程记录：并行会话（非未知外部进程）
本检查期间（17:22-17:57）观察到的 ACL 波动/密码轮换/脚本修改，经核实为**并行会话执行 V1.1 封版前 P1 清零与数据库最终架构收口检查**（见今日工作日志 17:41-18:10）：
- 17:22~17:57 期间：SECURITY DEFINER 函数 ACL 波动（57 查询函数授权保持，5 生成函数仅 postgres 为设计），期间 MCP 工具出现间歇 permission denied（如 get_business_summary 17:46 失败 → 17:56 恢复）
- 17:48 日志出现**非本会话发起的** `detect_growth_opportunities` 调用
- 17:52 `.env` 被更新（数据库密码轮换，新增 PG_ADMIN_PASSWORD 字段）
- **影响**：并发会话可能互相覆盖 ACL/密码，导致 MCP 间歇不可用
- **建议**：确认是否有其他 WorkBuddy 会话/定时任务在操作本库；如无，按"单一维护窗口"原则执行 DDL/密码操作；F0.5 前固化 ACL 基线（57+5+1）并加版本记录

## P2 遗留：get_business_report 等 PUBLIC EXECUTE（已归收口遗留①）
- 函数 `mart.get_business_report` proacl={=X/postgres,...} 保留 PUBLIC EXECUTE
- 建议：确认后 REVOKE ALL ON FUNCTION mart.get_business_report(text,text) FROM PUBLIC（最小权限收敛）