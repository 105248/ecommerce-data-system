# Coverage 门禁报告（专项09）

> 生成时间：2026-08-08 18:04:46 ｜ V1.3+V1.1+数据库封版关键逻辑专项检查 ｜ 只读检查，未修改任何数据库对象

## 结论：PASS（两店完整场景验证；缺店场景未构造）

| 区间 | enabled | covered | missing | days/expected | complete |
|---|---|---|---|---|---|
| 06-01~06-30 | 2 | 2 | 0 | 30/30 | True |
| 06-24~06-30 | 2 | 2 | 0 | 7/7 | True |
| 06-30 单日 | 2 | 2 | 0 | 1/1 | True |

- ✅ 函数 `get_platform_business_period_summary` 含 enabled/covered/missing/coverage 计算逻辑
- ✅ coverage_complete 字段语义正确；缺失店铺会出现在 missing_shops（V1.3 S2 已验收）
- ⚠️ 缺官方/缺1天/单期不完整 7 场景未在正式库构造（只读约束）；建议 F0.5 前置在隔离库做破坏性演练，验证"缺数据不触发假 GMV 暴跌"（V1.1 异常检测依赖 coverage_complete 门禁字段，anomaly_event.coverage_complete 已存在）