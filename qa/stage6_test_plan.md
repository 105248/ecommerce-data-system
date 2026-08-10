# Stage6 测试计划（test_plan）

> 《PostgreSQL mart经营分析层 V1.0｜阶段6 全链路错误检查、回归测试与最终封版验收》
> 日期：2026-08-08 ｜ 范围：Excel → core → mart → MCP → AI 全链路

## 目标

最终确认六件事：数据有没有错 / 指标公式有没有错 / 汇总口径有没有错 / Function 有没有逻辑错误 / MCP 有没有调用错误 / AI 有没有理解解释错误。

## 执行顺序

| 阶段 | 内容 | 位置 |
|---|---|---|
| 6A | 底层数据完整性（core 9表/店铺/日期） | qa/s6a_data.sql |
| 6B | 原始Excel → core 对账（抽样） | qa/s6b_excel_reconcile.py |
| 6C | V1.4指标规则总检查 + AVG扫描 + source_only | qa/s6c_rules.sql + qa/s6c_avg_scan.py |
| 6D | TOTAL/DETAIL口径 + 类目层级 + Scope双规则 | qa/s6d_total.sql |
| 回归 | Daily Mart / Period / Compare / Rank / Contribution | qa/s6e_regression.sql |
| MCP | Tool回归 + 安全 + 无自算指标 | qa/s6f_mcp.py |
| AI | 42题重跑 + 诱导题 + 30题数字一致性 | qa/s6g_ai.py |

## 抽样要求（6B）

- ≥10个日期、≥5个商品、≥5个账号、≥3个类目、全部5载体、全部6价格带、全部终端、首购/复购

## 错误分级

| 等级 | 定义 | 示例 | 是否阻止封版 |
|---|---|---|---|
| P0 | 数据/金额严重错误 | TOTAL重复SUM、比例除错100倍 | 必须阻止 |
| P1 | 核心业务口径错误 | 商品TOTAL重建、退款率AVG | 必须阻止 |
| P2 | 查询/展示逻辑错误 | 排名错误、百分点显示错误 | 必须修复 |
| P3 | 文案/体验问题 | Tool说明不够清楚 | 可记录后修(V1.1) |

## 封版门槛

P0=0、P1=0、P2=0；core完整性/Excel对账/V1.4/TOTAL/source_only/Daily Mart/Period/Comparison/Ranking/Contribution/MCP/只读/AI路由/AI数字一致性 全部 PASS。
