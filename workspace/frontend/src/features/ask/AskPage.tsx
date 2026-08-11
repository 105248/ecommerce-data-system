// F1.1 /ask 问数据（智能助手占位；F1.0.5 接入 MCP 自由查数）
// 链路：自然语言 → 智能体 → MCP → 正式 mart Function → 数据库结果 → 表格 + 解释
export function AskPage() {
  return (
    <div>
      <h1>问数据</h1>
      <div className="sub">智能助手（规划中，接入 F1.0.5）</div>
      <div className="card">
        <div style={{ padding: '18px 0', fontSize: 14, color: '#374151', lineHeight: 1.9 }}>
          这里将支持自然语言直接查数，例如：<br />
          「鱼子酱品线最近 30 天怎么样？」<br />
          「两家店最近 7 天差异？」<br />
          「退款率最高的 20 个商品？」<br />
          「导出成 Excel。」
        </div>
        <div className="trend-note">
          链路：自然语言 → 智能体 → MCP → 正式 mart Function → 数据库结果 → 表格 + 解释。
          智能体禁止自行 SUM / AVG / 算退款率 / 算投放费比 / 模糊商品名聚合——全部走正式白名单计算。
        </div>
      </div>
    </div>
  )
}
