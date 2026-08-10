# V1.1 Stage1｜经营指标诊断基础层 — README

> 阶段性质：V1.1 的基础数据层。只建设"诊断所需的统一指标、统一周期、统一对象、统一快照与统一数据质量状态"。
> **本阶段不做异常判定、不做原因诊断、不做机会评分、不做每日行动清单、不做 AI 经营结论。**

## 一、交付文件

| 文件 | 说明 |
|---|---|
| `01_diagnostic_foundation.sql` | 3 张注册表（指标 31 / 对象 7 / 周期 6）+ `resolve_diagnostic_period` + 2 个目录函数（SECURITY DEFINER） |
| `02_diagnostic_snapshot.sql` | 主函数 `get_diagnostic_snapshot` + `_diag_shop` |
| `02b_diagnostic_snapshot_scope.sql` | `_diag_scope`（18 Scope） |
| `03a_diagnostic_snapshot_product_category.sql` | `_diag_product` / `_diag_category` |
| `03b_diagnostic_snapshot_carrier_account.sql` | `_diag_carrier` / `_diag_account` |
| `04_diagnostic_security.sql` | 权限收紧（PUBLIC 无 EXECUTE、agent_readonly 3 入口、内部函数不授权） |
| `05_diagnostic_cn_layer.sql` | 中文数据层 4 个 View |
| `diagnostic_metric_catalog.md` | 诊断指标目录（31 条） |
| `diagnostic_domain_support_matrix.md` | 域-指标支持矩阵 |
| `qa\v1.1_stage1_test_results.md` | 测试结果汇总 |

## 二、数据库对象清单

| 对象 | 类型 | 说明 |
|---|---|---|
| `mart.diagnostic_metric_rule` | 表 | 31 条诊断指标注册 |
| `mart.diagnostic_entity_rule` | 表 | 7 域注册（product_line=disabled） |
| `mart.diagnostic_period_rule` | 表 | 6 周期注册（1d/3d/7d/14d/30d/custom） |
| `mart.resolve_diagnostic_period(text,date,int)` | 函数 | 等长前置周期解析 |
| `mart.get_diagnostic_supported_metrics()` | 函数 | 诊断指标目录（SECURITY DEFINER） |
| `mart.get_diagnostic_entity_metrics(text)` | 函数 | 域指标清单（SECURITY DEFINER） |
| `mart.get_diagnostic_snapshot(...)` | 函数 | **统一诊断快照**（SECURITY DEFINER，核心） |
| `mart._diag_shop/_scope/_product/_carrier/_account/_category` | 函数 | 6 域内部实现（不对外授权） |
| `中文数据.诊断指标规则 / 诊断对象规则 / 诊断周期规则 / 经营诊断快照` | View | 中文可读层 |

## 三、快照调用示例

```sql
-- 单店整体：最近 7 天（上期=等长前置 7 天）
SELECT * FROM mart.get_diagnostic_snapshot('弹动官方旗舰店','2026-06-24','2026-06-30','shop');

-- 全部 18 Scope
SELECT * FROM mart.get_diagnostic_snapshot('弹动官方旗舰店','2026-06-24','2026-06-30','scope');

-- 商品 TOP100（未指定对象 → 当前期 user_pay 前 100）
SELECT * FROM mart.get_diagnostic_snapshot('弹动官方旗舰店','2026-06-24','2026-06-30','product');

-- 指定商品（排名 = 全量商品排名，非单对象内排名）
SELECT * FROM mart.get_diagnostic_snapshot('弹动官方旗舰店','2026-06-24','2026-06-30','product',NULL,NULL,'<product_name>');

-- 载体（自营） / 账号（合作） / 类目（L3）
SELECT * FROM mart.get_diagnostic_snapshot('弹动官方旗舰店','2026-06-24','2026-06-30','carrier','自营');
SELECT * FROM mart.get_diagnostic_snapshot('弹动官方旗舰店','2026-06-24','2026-06-30','account','合作');
SELECT * FROM mart.get_diagnostic_snapshot('弹动官方旗舰店','2026-06-24','2026-06-30','category');
```

## 四、关键口径（勿改）

1. **周期**：`previous_end = current_start - 1`；`previous_start = previous_end - (current_days-1)`（等长前置，无同比）。
2. **防重**：deal 域仅取 `sale_scope='全部' AND carrier_type='全部' AND ad_period='不限'`（平台汇总行）。
3. **比率**：一律 `SUM(分子)/NULLIF(SUM(分母),0)`，禁止 AVG(日比率)。效率=加权源比率。
4. **排名**：全体排名 → 再筛选；退款率 ASC（越低越好），其余 DESC。product 用 `carrier='全部'` 独立 TOTAL。
5. **carrier**：排除 `account_channel IN ('全域投放时段','标准+品牌投放')`（special_overlap 治理，与 carrier_period 一致）。
6. **贡献**：域内占比（denominator_type=domain）；product 双分母（域/全店）语义保留。
7. **data_status**：OK / NO_CURRENT_DATA / NO_PREVIOUS_DATA / CURRENT_INCOMPLETE / PREVIOUS_INCOMPLETE / BOTH_INCOMPLETE / UNRECALCULABLE / UNSUPPORTED_DOMAIN_METRIC。
8. **NULL 保持 NULL**：上期无数据 → previous_value=NULL、relative_change=NULL、data_status=NO_PREVIOUS_DATA；上期=0 → relative_change=NULL、calculation_status=PREVIOUS_ZERO。

## 五、MCP

- 新增 2 工具：`get_diagnostic_snapshot` / `get_diagnostic_supported_metrics`（MCP 工具总数 27→29）。
- `mcp_server/tools/diagnostic_tools.py`；agent_readonly 通过 SECURITY DEFINER 主函数访问，core 不可直读。

## 六、验收状态

✅ 72 项一致性验收 0 差异（值/排名/贡献 vs 现有 Period/Rank/Contribution 函数）  
✅ 周期 1/3/7/14/30 天 + 随机区间；NULL/无数据处理符合规范  
✅ 性能：单对象 8ms、TOP100 商品 7 天 36ms、18 Scope 13ms（目标 <2s / <10s）  
✅ 安全：PUBLIC 无 EXECUTE；agent_readonly 仅 3 入口；core 无直读；内部 _diag_* 拒绝  
✅ 旧系统回归：全店 30 天 9,397,490.90 / 结算 9,461,162.26 / 退款 1,556,715.99 不变；field_mapping 448 / metric 106 / whitelist 49  
✅ P0=0 P1=0 P2=0

**本阶段不创建**：anomaly_event / opportunity_event / priority_event（属后续阶段）。
