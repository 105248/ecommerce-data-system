# mart V1.0 最终发布检查清单（release_checklist）

> 项目：PostgreSQL mart经营分析层 V1.0 ｜ 封版：2026-08-08

| # | 检查项 | 标准 | 结果 |
|---|---|---|---|
| 1 | core 完整性 | 9 表 = 18809 行 | ✅ PASS |
| 2 | Excel 抽样对账 | 54/54 一致 | ✅ PASS |
| 3 | V1.4 规则 | 96 条 / auto 79 | ✅ PASS |
| 4 | 剔除退款分母 | 12/12 = settlement_amount | ✅ PASS |
| 5 | TOTAL 规则 | deal/terminal/audience 合法；product 独立 | ✅ PASS |
| 6 | source_only | 单日源值/多日 NULL，不 AVG | ✅ PASS |
| 7 | Daily Mart | 10 天回归一致 | ✅ PASS |
| 8 | Period Function | 5 窗口 + 10 随机区间一致 | ✅ PASS |
| 9 | Comparison | 5 窗口紧邻等长；百分点正确 | ✅ PASS |
| 10 | Ranking | 先全体排名再过滤；各域正常 | ✅ PASS |
| 11 | Contribution | 分母权威；双分母不混 | ✅ PASS |
| 12 | MCP | 24/24 Tool；无 SQL Tool | ✅ PASS |
| 13 | 只读权限 | agent_readonly 写操作 7/7 拒绝 | ✅ PASS |
| 14 | AI Tool 路由 | 42 题路由正确 | ✅ PASS |
| 15 | AI 数字一致性 | 22/22 = core | ✅ PASS |
| 16 | 错误分级 | P0=0 / P1=0 / P2=0 | ✅ PASS |
| 17 | 比例原值 | 0.1972 / 9.625 保持 | ✅ PASS |
| 18 | 数据保护 | 未改 core/meta/audit 业务数据 | ✅ PASS |

## 交付物清单

- V1.4 元数据：`meta.metric_formula_rule`（96 条）+ 字典/公式规则
- core：9 张正式表（18809 行，2026-06）
- mart：9 Daily Mart + 31 条治理规则 + Scope Resolver（resolve_scope + period_scope_rule 18 个）
- Stage2：9 Period Function + metric_rule_v14
- Stage3：compare + 6 rank + 4 contribution + 白名单 39 条
- Stage4：agent_readonly + MCP Server（24 Tool）+ mcp.json
- Stage5：ai_layer（system_prompt/routing/metric_aliases/answer_templates/test_cases 42）
- Stage6：qa/（test_plan/bug_log/regression_results/checklist）

## 已知限制（V1.1 优化清单）

1. 同比无专用接口（如实说明）。
2. "今天"按现实日期解析（当前最新数据 2026-06-30）。
3. rank_terminals / rank_contents 未实现（官方 SQL 未提供，终端/内容用 summary）。
4. 30 天环比上期跨 5 月无数据 → "上期无数据"状态。
5. product 域与 deal 全店平台口径差异 ~785.56（保留，不强行校平）。

## 封版结论

**✅ V1.0 允许正式封版**（P0=0, P1=0, P2=0；全链路 15 项检查 PASS）。
