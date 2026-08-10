# V1.1 Snapshot 与异常引擎报告（专项14/15/16）

> 生成时间：2026-08-08 18:04:46 ｜ V1.3+V1.1+数据库封版关键逻辑专项检查 ｜ 只读检查，未修改任何数据库对象

## 结论：PASS

| 检查点 | 结果 | 证据 |
|---|---|---|
| Snapshot 状态机 | ✅ 实测 OK / NO_PREVIOUS_DATA | get_diagnostic_snapshot 分发到 8 个 _diag_* 内部函数 |
| PREVIOUS_ZERO 防护 | ✅ | 8 个 _diag_* 函数含 nullif/zero 分支（除0防护） |
| 异常 Low Base | ✅ | 8 条 anomaly_rule 全部配置 low_base_metric/value（如 A01 成交<5000 门禁） |
| 异常幂等 | ✅ 完全重复=0 | (chain_key,日期,域,实体,指标,类型) 重复=0；同链多实体=聚合语义 |
| 异常生命周期 | ✅ | status=OPEN(104)；同链跨日期=持续检测（triggered_period_count） |

> 构造型验证（低基数大变化 vs 高基数小变化）未执行正式库；anomaly_rule 门禁配置为设计证据，建议隔离库构造样本复核门禁效果。