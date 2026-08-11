// F1.1 /product-lines 品线（业务分析第一层）：品线表格 + 点击下钻标准商品
// 正式统计基于配置关系（meta 映射），非名称包含临时聚合；仅 CONFIRMED 进入正式汇总
import { useEffect, useState } from 'react'
import type { Filters } from '../../types'
import { api } from '../../services/api'
import { CapabilityNotice } from '../../components/CapabilityNotice'
import { yuan, esc } from '../../lib/format'

interface Line { product_line_code: string; product_line_name: string }
interface Member { master_product_code: string; master_product_name: string; enabled: boolean }
interface LineSummary { user_pay_amount: number | null; refund_amount_pay_time: number | null; mapped_member_count: number; expected_member_count: number; covered_shop_count: number; mapping_complete: boolean; data_coverage_complete: boolean }

export function ProductLinesPage({ f }: { f: Filters }) {
  const [lines, setLines] = useState<Line[]>([])
  const [members, setMembers] = useState<Record<string, Member[]>>({})
  const [sums, setSums] = useState<Record<string, LineSummary>>({})
  const [open, setOpen] = useState<string | null>(null)
  const [err, setErr] = useState('')
  useEffect(() => {
    setErr('')
    api<Line[]>('/master-data/product-lines').then(async r => {
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
        } catch { /* 无数据品线跳过 */ }
      }
      setLines(r.data); setMembers(mm); setSums(ss)
    }).catch(e => setErr(e.message))
  }, [f.sd, f.ed])
  return (
    <div>
      <h1>品线</h1>
      <div className="sub">品线 → 标准商品（跨店聚合，仅 CONFIRMED）｜ {f.sd} ～ {f.ed}</div>
      {err ? <CapabilityNotice state="ERROR" text={err} /> : (
        <div className="card">
          <table>
            <thead>
              <tr><th>品线</th><th className="num">当前金额</th><th className="num">退款</th><th className="num">标准商品数</th><th>状态</th></tr>
            </thead>
            <tbody>
              {lines.map(line => {
                const s = sums[line.product_line_code]
                const ms = members[line.product_line_code] || []
                return (
                  <>
                    <tr key={line.product_line_code} onClick={() => setOpen(open === line.product_line_code ? null : line.product_line_code)}
                      style={{ cursor: 'pointer', background: open === line.product_line_code ? '#f3f4f6' : undefined }}>
                      <td>
                        {esc(line.product_line_name)} <span className="badge blue">{esc(line.product_line_code)}</span>
                        <span style={{ fontSize: 11, color: '#9ca3af', marginLeft: 6 }}>{open === line.product_line_code ? '▲' : '▼'}</span>
                      </td>
                      <td className="num">{s?.user_pay_amount != null ? yuan(s.user_pay_amount) : '—'}</td>
                      <td className="num">{s?.refund_amount_pay_time != null ? yuan(s.refund_amount_pay_time) : '—'}</td>
                      <td className="num">{s?.mapped_member_count ?? ms.length}</td>
                      <td>
                        {s ? (
                          <span className={`badge ${s.mapping_complete && s.data_coverage_complete ? 'green' : 'amber'}`}>
                            {s.mapping_complete ? '映射完整' : `映射不完整(${s.mapped_member_count}/${s.expected_member_count})`}{s.data_coverage_complete ? '' : '·数据不完整'}
                          </span>
                        ) : <span className="badge gray">区间无数据</span>}
                      </td>
                    </tr>
                    {open === line.product_line_code && (
                      <tr key={`${line.product_line_code}-m`}>
                        <td colSpan={5} style={{ background: '#fafafa', padding: 0 }}>
                          <table style={{ margin: 8, width: 'calc(100% - 16px)' }}>
                            <thead><tr><th>标准商品</th><th>编码</th><th>状态</th></tr></thead>
                            <tbody>
                              {ms.map((m, i) => (
                                <tr key={i}>
                                  <td><a href="#/master-products">{esc(m.master_product_name)}</a></td>
                                  <td>{esc(m.master_product_code)}</td>
                                  <td><span className={`badge ${m.enabled ? 'green' : 'gray'}`}>{m.enabled ? '启用' : '停用'}</span></td>
                                </tr>
                              ))}
                              {!ms.length && <tr><td colSpan={3} className="empty">该品线暂无标准商品成员</td></tr>}
                            </tbody>
                          </table>
                        </td>
                      </tr>
                    )}
                  </>
                )
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
