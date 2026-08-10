# mart V1.0 Stage5｜AI 自然语言经营分析层

> 阶段5 定位：自然语言理解 → MCP Tool 选择 → 结果解释。
> 无新增经营计算 SQL（Stage1-3 已完成计算，Stage4 已封装 MCP）。

## 架构

```
用户自然语言
  ↓
AI Agent（WorkBuddy/OpenClaw，加载本目录 system_prompt）
  ↓ 路由规则 routing_rules.md
Stage4 MCP（24 工具，agent_readonly 只读）
  ↓
mart Function（Stage2/3）
  ↓
PostgreSQL core
```

## 目录

| 文件 | 作用 |
|---|---|
| `system_prompt.md` | Agent 系统提示词（角色、铁律、时间语义、工具路由、默认值、回答规范） |
| `routing_rules.md` | 自然语言意图 → Tool 路由表 + 时间解析 + 多轮继承 |
| `metric_aliases.json` | 指标别名治理（用户支付金额/退款率/客单价等 → metric_key） |
| `answer_templates.md` | 标准回答模板（金额/比例/环比/TOP/贡献/source_only/无数据/同比/为什么） |
| `test_cases.json` | 42 条真实问题测试集（解析期望 + 工具 + 参数 + 数字核对） |
| `README.md` | 本说明 |

## 使用方式（WorkBuddy）

1. 连接管理器信任 `mart-mcp`（mcp.json 已配置）。
2. 在对话中加载 `system_prompt.md` 作为系统指令（或由用户复述关键规则）。
3. 直接提问，Agent 按路由规则调用 MCP 工具并解释结果。

## 关键语义（务必遵守）

- 最近 N 天 = 以数据库 max_date（2026-06-30）为终点。
- 今天 = 现实日期，无数据则如实说明，不替换成最新一天。
- 比例展示：0.1972 → 19.72%，9.625 → 962.50%，不按 >1 改变语义。
- source_only 多日 NULL：不 AVG，说明"无已确认跨期口径"。
- 环比走 compare_business（N天vs前N天由数据库算）。
- 同比：暂无专用接口，如实说明。
- 全店/自营/合作/商品卡/短视频等用已确认 Scope；商品/账号/类目不得混用 TOTAL。
- "更多账号"是合作聚合桶，不是具体达人。

## 验收

42 条测试用例见 `test_cases.json`；逐题记录：解析结果、工具选择、参数、数字一致率、幻觉检查、不直接 SQL 检查。完整验收见《mart V1.0 阶段5｜AI自然语言经营分析验收报告》。
