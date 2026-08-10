# Opportunity 与 Priority 报告（专项19/20/21）

> 生成时间：2026-08-08 18:04:46 ｜ V1.3+V1.1+数据库封版关键逻辑专项检查 ｜ 只读检查，未修改任何数据库对象

## 结论：PASS

| 检查点 | 结果 | 证据 |
|---|---|---|
| 权重归一 | ✅ | 8 条 opportunity_rule 权重和=100（100 制归一） |
| available_weight≥70% | ✅ | 209/264 事件 available_weight<0.7 → 不输出正式机会分（门禁生效） |
| Peer Pool 分池 | ✅ | benchmark_pool 按域：master_product=31 / shop_product=13 / carrier=6（不混池） |
| Priority 链去重 | ✅ | 风险 TOP5 含 3 个不同 chain（shop/master_product/carrier），同一链未占满 |
| dedupe_group_key | ✅ | 组内最多 9 条（同链跨期持续跟踪，occurrence 语义） |
| 风险机会并存 | ✅ | 同店同日期 3 组并存；anomaly_event(104) + opportunity_event(264) 独立评估 |

> SP20 样本注：TOP5 中 S1|master_product 链出现 3 次但对应**不同商品实体**（鱼子酱洗发水/椰子洗护等），属合理（同链多实体聚合），非去重失效。