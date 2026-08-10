# Stage6 回归测试结果（regression_results）

> 2026-08-08 ｜ 全链路：Excel → core → mart → MCP → AI

## 一、阶段6A 数据完整性 ✅

| 检查项 | 结果 |
|---|---|
| core 9表总行数 | **18809** ✅（deal 2160/carrier 3203/account 1953/content 4294/terminal 450/category 439/product 5771/price_band 179/audience 360） |
| 每表日期范围 | 全部 2026-06-01 ~ 2026-06-30 ✅ |
| 非法 shop_id | 9 表全 0 ✅ |
| 未来日期 | 9 表全 0 ✅ |
| 日期完整性 | 每表 expected=30/actual=30/missing=0 ✅ |
| 业务键唯一性 | 9 表重复=0 ✅（deal 按 scope×carrier×period 唯一等） |
| meta.shop | 1 店无重复 code，enabled=true ✅ |
| NULL 异常 | deal 关键字段 NULL=0 ✅ |

## 二、阶段6B 原始Excel → core 对账 ✅

**54/54 PASS**（随机10日期 × 全维度抽样）：
- deal 3 天用户支付金额完全一致（323303.49/339261.78/268830.30）
- product 5 商品完全一致（89/1695.95/988.69/196/2488.97）
- price_band 12 项（6 带×2 天）完全一致
- audience 4 项（复购/首购×2 天）完全一致
- terminal 22 项（4 终端×售卖类型×2 天）完全一致
- account 3 项、category 3 项完全一致
- 比例原值 **0.1972 / 9.625 保持原值**（无 100 倍换算）✅

## 三、阶段6C V1.4 规则 ✅

- 规则总数 **96** ✅；auto_use_allowed=true **79** ✅
- 12 条剔除退款：denominator=settlement_amount **12/12**，net_transaction_amount 残留 **0** ✅
- **AVG 扫描**：mart 函数源码无 AVG(比例/均值) ✅；MCP Python 无自算指标(sum/avg/ratio) ✅
- **source_only**：单日有值（两日发货率 0.89385821、成交笔单价、复购率），多日全 NULL ✅；无 source_only 被标记跨期可重算（=0）✅

## 四、阶段6D TOTAL/DETAIL 口径 ✅

| 关系 | diff |
|---|---|
| deal 全部 = 自营+合作（30天） | **0.00** ✅ |
| deal 全部载体 = 5载体之和（30天） | **0.00** ✅ |
| terminal 整体 = 明细之和（06-01） | **0.00** ✅ |
| audience carrier=全部 = 5载体之和（06-01） | **0.00** ✅ |
| product 全部(独立TOTAL) ≠ 明细之和（30天） | **303419.41**（保留差异）✅ |
| 类目层级 | L1=45/L2=137/L3=257 行，不混 ✅ |
| Scope 双规则 | **resolve_scope vs period_scope_rule 12/12 完全一致** ✅ |

## 五、Daily Mart 回归 ✅

shop_daily 随机 10 天（06-01/04/08/11/15/18/21/24/27/30）= core 合法 TOTAL，**10/10 PASS**（如 06-01=323303.49 等）。

## 六、Period Function 回归 ✅

- 5 窗口（1/3/7/15/30天）= 直接 SQL，**5/5 PASS**（如 30天=9397490.90）
- 10 随机区间 = 直接 SQL，**10/10 PASS**（diff 全 0.00）

## 七、Comparison 回归 ✅

- 5 窗口（1/3/7/10/15天）：previous_end = current_start-1（gap=1）、天数相等，**5/5 PASS**
- 百分点：0.08→0.10 ⇒ absolute=0.02、percentage_point=**2.00**、relative=0.25，**展示规则 PASS**（+2 个百分点/相对+25%）

## 八、Ranking 回归 ✅

- **先全体排名再过滤**：过滤商品 3777721060405936555 后 current_rank=**3**（非第1）✅ 经典错误未发生
- 商品 TOP10、合作账号 TOP10（排除更多账号）、类目 L2/L3、5 载体、6 价格带、2 人群 全部正常

## 九、Contribution 回归 ✅

- 商品卡 34.08% / 自营 93.20% / 合作 6.80%（分母=deal全店TOTAL）✅
- product 双分母（商品域 9396705.34 vs 全店 9397490.90 保留平台差异）✅
- account 分母来自 deal 权威 TOTAL ✅

## 十、MCP 回归 ✅

- **24/24 Tool 全量调用 PASS**（含 1 个 P3 测试断言误判，已确认非业务缺陷）
- **无 unrestricted SQL Tool** ✅
- **agent_readonly 安全 9/9**：SELECT/EXECUTE ✅；INSERT/UPDATE/DELETE/TRUNCATE/CREATE/DROP/ALTER 全拒绝 ✅

## 十一、AI 数字一致性 ✅

- **22/22 PASS**（30 题中的机器核验部分）：各 scope 金额、单日、最近7天、环比本期+上期、退款率、客单价、件单价、点击成交转化率、商品 TOP1、商品金额/域分母、合作账号 TOP1、更多账号、三级类目 TOP1、商品卡占全店、复购金额 —— **AI/MCP 数字 = core 合法 SQL**（金额差 0.00、比例差 0）
- **诱导题 4/4**：拒绝 AVG（加权 0.1651 vs AVG 0.1648 不同）、商品独立TOTAL 不重建、无数据不估算（NO_DATA）、无 SQL 工具 ✅

## 十二、BUG 汇总

| 等级 | 数量 | 说明 |
|---|---|---|
| P0 | **0** | - |
| P1 | **0** | - |
| P2 | **0** | - |
| P3 | **2** | 均为测试脚本断言问题（L2 类目数写死 10、psql -c 中文编码），已修复，非业务缺陷 |

**结论：P0=0、P1=0、P2=0，全链路回归通过，满足封版条件。**
