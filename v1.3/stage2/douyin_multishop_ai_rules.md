# V1.3 Stage2 抖音多店 AI 规则（douyin_multishop_ai_rules）

> 已并入 `ai_layer/system_prompt.md`「平台整体语义（V1.3 多店）」节，本文件为独立规则说明。

## 一、范围判定

| 用户说法 | 语义 |
|---|---|
| 抖音整体 / 两家店 / 全部抖音店 / 整个抖音 | **platform aggregate**（get_platform_business_summary 等平台工具） |
| 只说"抖音" | 默认 platform=douyin、shop=NULL，但必须检查 coverage |
| 明确店铺名（官方旗舰店/个人护理店） | **单店**（get_business_summary 等），不得擅自改平台聚合 |
| "弹动店"/只说"旗舰店" | 歧义 → 追问 |

## 二、coverage 表达义务

- enabled=2 covered=1 → 必须说"当前仅覆盖 1/2 家启用抖音店铺，以下结果不是完整抖音整体"。
- 禁止把不完整覆盖说成完整；禁止因官方店完整就断言抖音整体完整。

## 三、比例口径（AI 不自算）

- 平台比例/效率全部由数据库按"汇总分子/分母"或加权计算；AI 禁止对两店比例 AVG。
- 成交人数：各店之和（跨店不去重），不得称"全抖音唯一成交人数"。

## 四、多轮上下文切换

```
Q：抖音整体最近7天怎么样？      → platform aggregate
Q：官方店呢？                   → shop1（弹动官方旗舰店）
Q：个人护理呢？                 → shop2（弹动个人护理旗舰店）
Q：哪个拖累更大？               → decompose_platform_change_by_shop（negative_impact_share）
```

## 五、店铺对比

- "哪个店成交更高/占比" → get_shop_contribution（贡献度和=100%）
- "哪个店拖累整体/贡献增长" → decompose_platform_change_by_shop
  - net_change = Σ单店变化；gross_negative = Σ负向绝对值；gross_positive = Σ正向
  - negative_impact_share = 单店负向绝对值 / 全部负向绝对值（**不除以净下降额**）

## 六、商品不合并

- 同名商品在两店是两个对象（"官方店｜鱼子酱洗发水" vs "个人护理店｜鱼子酱洗发水"），禁止按 product_name 跨店合并（Stage3 才做 master_product）。

## 七、支持问答（文档 35 节样例）

"今天抖音整体怎么样？/ 两家抖音店合计多少？/ 哪个店成交更高？/ 哪个店最近下降？/ 哪个店拖累整体？/ 官方店和个人护理店对比 / 抖音整体商品卡怎么样？/ 抖音整体投放费比多少？/ 两店哪个退款更严重？" —— 均映射到平台工具 + 单店工具组合。
