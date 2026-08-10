// F1.0.4 /product-lines 品线（结构 + 经营汇总；F1.0.2 白名单函数）
import { useEffect, useState } from 'react'
import type { Filters } from '../types'
import { api } from '../services/api'
import { CapabilityNotice } from '../components/CapabilityNotice'
import { yuan, esc } from '../lib/format'

interface Line { product_line_code: string; product_line_name: string }
interface Member { master_product_code: string; master_product_name: string; enabled: boolean }
interface LineSummary { user_pay_amount: number | null; refund_amount_pay_time: number | null; mapped_member_count: number; expected_member_count: number; covered_shop_count: number; mapping_complete: boolean; data_coverage_complete: boolean }

export function ProductLinesPage({ f }: { f: Filters }) {
  const [lines, setLines] = useState<Line[]>([])
  const [members, setMembers] = useState<Record<string, Member[]>>({})
  const [sums, setSums] = useState<Record<string, LineSummary>>({})
  const [err, setErr] = useState('')
  useEffect(() => {
    setErr('')
    api<Line[]>('/master-data/product-lines').then(async r => {
      setLines(r.data)
      const mm: Record<string, Member[]> = {}
      const ss: Record<string, LineSummary> = {}
      for (const line of r.data) {
        try {
          const m = await api<Member[]>('/master-data/product-line-members', { product_line_code: line.product_line_code })
          mm[line.product_line_code] = m.data
        } catch { mm[line.product_line_code] = [] }
        try {
          const s = await api<LineSummary>('/product-lines/summary', { product_line_name: line.product_line_name, start_date: f.sd, end_date: f.ed })
          ss[line.product_line_code] = s.data
        } catch { /* NO_DATA 合法 */ }
      }
      setMembers(mm); setSums(ss)
    }).catch(e => setErr(e.message))
  }, [f.sd, f.ed])
  return (
    <div>
      <h1>品线分析</h1>
      <div className="sub">Product Line → Master Product → 店铺商品（正式跨店聚合，仅 CONFIRMED）｜ {f.sd} ～ {f.ed}</div>
      {err ? <CapabilityNotice state="ERROR" text={err} /> : lines.map(line => {
        const s = sums[line.product_line_code]
        const ms = members[line.product_line_code] || []
        return (
          <div className="card" key={line.product_line_code}>
            <h3>{esc(line.product_line_name)} <span className="badge blue">{esc(line.product_line_code)}</span> <span className="badge gray">{ms.length} 个 Master Product</span></h3>
            {s && (
              <>
                <div className="kpis" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(140px,1fr))', gap: 8, margin: '8px 0' }}>
                  <div className="kpi"><div className="l">用户支付金额</div><div className="v">{yuan(s.user_pay_amount)}</div></div>
                  <div className="kpi"><div className="l">退款金额(支付时间)</div><div className="v">{yuan(s.refund_amount_pay_time)}</div></div>
                  <div className="kpi"><div className="l">映射 Master Product</div><div className="v">{s.mapped_member_count}</div></div>
                  <div className="kpi"><div className="l">覆盖店铺</div><div className="v">{s.covered_shop_count}</div></div>
                </div>
                <div className="trend-note">映射完整性：{s.mapping_complete ? '完整' : '不完整'}（{s.mapped_member_count}/{s.expected_member_count}）｜ 数据覆盖：{s.data_coverage_complete ? '完整' : '不完整'}｜ 结算/投放/成交为品线粒度未支持指标</div>
              </>
            )}
            <table>
              <thead><tr><th>Master Product</th><th>编码</th><th>状态</th></tr></thead>
              <tbody>
                {ms.map((m, i) => (
                  <tr key={i}>
                    <td><a href="#/master-products">{esc(m.master_product_name)}</a></td>
                    <td>{esc(m.master_product_code)}</td>
                    <td><span className={`badge ${m.enabled ? 'green' : 'gray'}`}>{m.enabled ? '启用' : '停用'}</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )
      })}
    </div>
  )
}
