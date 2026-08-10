# 06｜F0.5 HTTP API 准备检查

> 数据库最终架构收口检查｜封版版 V1.0｜第八阶段
> 检查日期：2026-08-08｜本次**不开发 API**，仅判定每个正式接口的 HTTP 复用状态

---

## 一、判定标准

| 状态 | 定义 | F0.5 动作 |
|---|---|---|
| HTTP_READY | 零包装直接给 Backend 复用 | 直接映射 REST 路由 |
| HTTP_NEEDS_WRAPPER | 需薄包装（参数校验/JSON 结构/错误码） | Backend 建 wrapper 层 |
| HTTP_NOT_REQUIRED | 不面向 HTTP（内部/批处理/目录） | 不暴露 |
| HTTP_NOT_READY | 依赖未就绪 | 暂不暴露 |

---

## 二、状态分布（54 个正式接口）

| 状态 | 数量 | 说明 |
|---|---|---|
| HTTP_READY | 4 | 基础目录/健康/行动列表（无业务参数或仅日期+平台）|
| HTTP_NEEDS_WRAPPER | 49 | 经营查询函数（需参数校验+返回结构封装）|
| HTTP_NOT_REQUIRED | 1 | get_import_history（内部目录）|
| HTTP_NOT_READY | 0 | — |

---

## 三、HTTP_READY 接口（F0.5 可直接映射）

| interface_code | 建议 REST 路由 | 说明 |
|---|---|---|
| mart.get_daily_business_brief | `GET /api/v1/daily/brief` | 平台+日期，返回行动摘要，零包装 |
| mart.get_daily_risk_priorities | `GET /api/v1/daily/risk-priorities` | 平台+日期，JSON 直出 |
| mart.get_daily_opportunity_priorities | `GET /api/v1/daily/opportunity-priorities` | 同上 |
| mart.get_daily_action_list | `GET /api/v1/daily/actions` | 平台+日期+类型过滤 |

## 四、HTTP_NEEDS_WRAPPER 主要接口（49 个，典型 8 类）

| 类别 | 接口示例 | wrapper 要点 |
|---|---|---|
| 经营总览 | get_business_period_summary / get_platform_business_period_summary | shop_name/scope_key/metric_key 参数校验；ratio 保留小数；scope 默认全店 |
| 环比 | compare_business_period / compare_platform_business / compare_advertising_period | 时间窗口语义（本期+上期字段）；百分点点位变化标注 |
| 排名 | rank_products / rank_carriers / rank_categories / rank_accounts / rank_audiences / rank_price_bands | sort_by 白名单校验（复用 analysis_metric_whitelist）；limit 上限 |
| 贡献/拆解 | get_*_contribution / decompose_* | 分母口径说明字段（全店 vs 域内）|
| 诊断/漏斗 | get_diagnostic_snapshot / get_funnel_diagnosis / get_diagnostic_result | 大 JSON；domain/entity 参数校验；状态枚举映射 |
| 异常/机会 | get_anomalies / get_growth_opportunities / get_opportunity_summary / get_entity_* | status/severity 枚举白名单；分页 |
| 主数据 | list_master_products / get_master_product_members / resolve_master_product / list_product_lines | 只读 GET；映射状态枚举 |
| 覆盖/目录 | get_data_coverage / get_metric_catalog / get_mapping_conflicts / get_unmapped_products | 简单 GET，建议直接 READY |

## 五、F0.5 建设建议（不开发，仅预留）

1. **直接复用**：4 个 READY 接口无需任何数据库改动；49 个 NEEDS_WRAPPER 仅需 Backend 薄封装，**数据库零修改**。
2. **安全模型**：F0.5 Backend reader 角色沿用 `agent_readonly` 最小权限（仅 EXECUTE 白名单函数 + 只读 SELECT 白名单视图），不新增 core 权限。
3. **公式唯一性**：Backend 只调用 mart 函数，禁止在 Node/Python 侧重算任何经营指标（与 MCP 同约束）。
4. **不暴露**：`get_import_history` 保持内部；后台写库函数（detect_*/generate_*）绝不通过 HTTP 暴露。
5. **版本策略**：接口目录 03/04 即 F0.5 唯一依据，F0.5 不重新研究数据库。

---

## 六、结论

**F0.5 HTTP API 可直接复用 4 个接口，49 个接口仅需 Backend 薄包装，数据库侧无需任何结构调整。HTTP API 准备状态 = 通过。**
