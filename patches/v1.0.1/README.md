# mart V1.0.1 补丁包说明

> PostgreSQL mart经营分析层 V1.0.1｜抖音成交分析 61 列全字段兼容补丁
> 日期：2026-08-08

## 目录结构

```
patches/v1.0.1/
├── 00_preflight/            # Preflight 基线检查与备份
│   └── backup/              # meta/mart/full schema SQL + mcp_server/ai_layer 目录备份
├── 01_schema_mapping_patch.sql   # 前三张成交表 61列 field_mapping 重建 (V1.0.1, 183条)
├── 01b_core_add10.sql            # core.douyin_deal_daily ALTER TABLE +10投放字段 +COMMENT
├── 02_metric_rules.sql           # metric_formula_rule +10条投放规则 (96→106)
├── 03a_business_fn_10col.sql     # get_business_period_summary 重建 (+10投放列)
├── 03b_advertising_fns.sql       # get_advertising_period_summary / compare_advertising_period 新增
├── 03c2_whitelist_rebuild.sql    # analysis_metric_whitelist 重建 (+10条 advertising)
├── 03d_shopdaily.sql             # mart.shop_daily 重建 (+10投放字段)
├── 03e_metric_view.sql           # mart.metric_rule_v14 更新 (含V1.0.1, 106条)
├── 04_cn_view_patch.sql          # 中文数据.抖音成交日报 重建 (68列, 原样中文表头)
├── 03_mcp_patch/                 # MCP: tools/advertising_tools.py + server.py 注册 (24→26)
├── 04_ai_patch/                  # AI: routing_rules/metric_aliases/system_prompt/answer_templates 更新
└── tests/                        # 全部验证脚本与证据
```

## 核心变更

| 项 | 说明 |
|---|---|
| field_mapping | 前三张表 51→61 列完整重建（14-51列顺序变化, 按新表头 source_column_order 1-61）；总数 418→**448** |
| importer | 已按**表头名匹配**（既有）；新增：未知字段/重复表头**阻止导入**、legacy_51 兼容（缺10新字段→允许置NULL）、`--force` 受控覆盖 |
| core.deal_daily | +10 投放字段（消耗2/贡献1+占比1/费比2/效率4），NUMERIC+中文COMMENT，比例存原值、效率存倍数 |
| metric_formula_rule | +10 规则：3 sum / 2 ratio（贡献占比、投放费比 分母=settlement_amount）/ 综合费比+4效率 = weighted_source_ratio |
| mart | shop_daily/period_summary +10列；新增 get_advertising_period_summary / compare_advertising_period（SECURITY DEFINER 固定 search_path） |
| 中文层 | 抖音成交日报 58→**68列**（10投放字段原样中文表头）；11表 missing_in_core=0 / missing_in_chinese_view=0 |
| MCP | 24→**26** 工具（get_advertising_summary / compare_advertising） |
| AI | 路由关键词（投放/费比/效率/ROI）、别名11组、效率倍数不显示百分比 |

## 验证结论（P0=P1=P2=0）

- dry-run：18809 行 / 0 异常 / 0 未知 / 0 重复表头 / 0 缺失 / 11表 current_61
- legacy_51：51列文件可导入（profile=legacy_51，10新字段置NULL）
- 覆盖导入：batch9 success 18809 行（replace_period 事务内）
- **21600 值全量对账：0 不匹配**（2160行×10新字段 Excel=core）
- 列错位专项：504 值 0 不匹配（header-name 匹配生效）
- 旧 V1.0 回归：全店 9397490.90 / 商品卡 3202866.49 / 自营 8758528.79 / 合作 638962.11 全部不变
- 新投放指标：全店30天 消耗被投3918524.13/绑定4016358.22/贡献11074837.77/占比98.25%/费比42.45%/综合44.88%/效率2.3755等（加权非AVG，7天证明 diff=0.000912）
- MCP 数字一致性：17/17 PASS；环比效率无百分点
- 安全：新函数 SECURITY DEFINER+固定 search_path、PUBLIC 无 EXECUTE、agent_readonly 仅白名单、core 无直读
- 比例原值：0.1972 / 9.625 不变；core 18809；18 Scope 18/18

**✅ mart V1.0.1 抖音61列全字段兼容补丁正式通过**
