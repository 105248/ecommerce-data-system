// F1.0.4 共享组件：MetricCard（纯展示；环比 chg 必须来自 API 字段，禁止前端 cur-prev）
import { fmt, pct, yuan } from '../lib/format'

export function MetricCard({ label, value, opts }: {
  label: string
  value: number | null | undefined
  opts?: { isRate?: boolean; chg?: number | null; goodWhen?: 'high' | 'low'; unit?: string }
}) {
  const v = opts?.isRate ? pct(value) : yuan(value)
  let chgHtml = ''
  if (opts?.chg !== null && opts?.chg !== undefined && value !== null && value !== undefined) {
    const d = opts.chg
    const up = d > 0.0001
    const dn = d < -0.0001
    const good = opts?.goodWhen === 'low' ? dn : up
    const cls = up || dn ? (good ? 'good' : 'bad') : 'flat'
    const txt = opts?.isRate
      ? (d >= 0 ? '+' : '') + (d * 100).toFixed(2) + ' pp'
      : (d >= 0 ? '+' : '') + fmt(d)
    chgHtml = `<div class="c ${cls}">较上期 ${txt}</div>`
  }
  return (
    <div className="kpi">
      <div className="l">{label}</div>
      <div className="v">{v}{opts?.unit ? ` ${opts.unit}` : ''}</div>
      {chgHtml ? <div dangerouslySetInnerHTML={{ __html: chgHtml }} /> : null}
    </div>
  )
}
