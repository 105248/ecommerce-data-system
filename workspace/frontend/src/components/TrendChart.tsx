// F1.0.4 共享组件：TrendChart（SVG 折线；数据来自正式 API 单次查询）
import type { TrendPoint } from '../types'
import { fmt } from '../lib/format'

export function TrendChart({ points, height = 130 }: { points: TrendPoint[]; height?: number }) {
  const vals = (points || []).map(p => p.metric_value).filter((v): v is number => v !== null && v !== undefined)
  if (!vals.length) return <div className="empty">当前区间无趋势数据</div>
  const w = 560
  const mx = Math.max(...vals)
  const mn = Math.min(...vals)
  const px = (i: number) => (i / (vals.length - 1 || 1)) * (w - 20) + 10
  const py = (v: number) => height - 20 - ((v - mn) / (mx - mn || 1)) * (height - 40)
  const pts = points.filter(p => p.metric_value !== null && p.metric_value !== undefined)
  const poly = pts.map((p, i) => `${px(i)},${py(p.metric_value as number)}`).join(' ')
  return (
    <svg viewBox={`0 0 ${w} ${height}`} style={{ width: '100%', maxHeight: 170 }}>
      <polyline points={poly} fill="none" stroke="#2563eb" strokeWidth={2} />
      <line x1={10} y1={height - 20} x2={w - 10} y2={height - 20} stroke="#e5e7eb" />
      {pts.map((p, i) => (
        <circle key={i} cx={px(i)} cy={py(p.metric_value as number)} r={2.5} fill="#2563eb">
          <title>{`${p.date}：${fmt(p.metric_value)}`}</title>
        </circle>
      ))}
    </svg>
  )
}
