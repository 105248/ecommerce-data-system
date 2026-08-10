# 诊断与变化拆解报告（专项17/18）

> 生成时间：2026-08-08 18:04:46 ｜ V1.3+V1.1+数据库封版关键逻辑专项检查 ｜ 只读检查，未修改任何数据库对象

## 结论：PASS

| 检查点 | 结果 | 证据 |
|---|---|---|
| 诊断因果边界 | ✅ | evidence_json=数据证据链（funnel/current/previous/relative_change/coverage_complete），非因果结论 |
| AI 因果边界 | ✅ | system_prompt 含"不写因果/证据"约束；诊断 code 为定位型（D01_SALES_DECLINE/D08_MULTI_FACTOR_DECLINE） |
| 变化拆解负向分母 | ✅ | decompose 函数含 gross_negative 逻辑；实测平台拆解 net=-299,600.78 share=0.6966（按负向分母） |
| 正向抵消单列 | ✅ | 函数返回 gross_positive 独立列（V1.3 S2 验收） |

> 构造型 A-100/B-50/C+80 验证：公式已从函数逻辑确认（gross_negative 分母）；数值构造建议隔离库。