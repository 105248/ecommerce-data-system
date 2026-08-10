// F1.0.4 /master-products（主档 + 合法排名，CONFIRMED 映射）
import { useEffect, useState } from 'react'
import type { Filters } from '../types'
import { api } from '../services/api'
import { CapabilityNotice } from '../components/CapabilityNotice'
import { yuan, esc } from '../lib/format'

interface RankRow { master_product_code: string; master_product_name: string; product_line_name: string; current_value: number; mapped_shop_count: number; mapping_complete: boolean }
interface MasterRow { master_product_code: string; master_product_name: string; enabled: boolean }

export function MasterProductsPage({ f }: { f: Filters }) {
  const [rank, setRank] = useState<RankRow[]>([])
  const [list, setList] = useState<MasterRow[]>([])
  const [err, setErr] = useState('')
  useEffect(() => {
    setErr('')
    api<RankRow[]>('/master-products/rank', { start_date: f.sd, end_date: f.ed, metric_key: 'user_pay_amount', limit: 50 })
      .then(r => setRank(r.data)).catch(() => setRank([]))
    api<MasterRow[]>('/master-data/products', { page_size: 100 }).then(r => setList(r.data)).catch(e => setErr(e.message))
  }, [f.sd, f.ed])
  return (
    <div>
      <h1>Master Product</h1>
      <div className="sub">公司商品主档（跨店统一主商品；CONFIRMED 映射进入正式跨店汇总）｜ {f.sd} ～ {f.ed}</div>
      {err ? <CapabilityNotice state="ERROR" text={err} /> : (
        <>
          <div className="card">
            <h3>Master Product 经营排名（用户支付金额）<span className="badge green">正式接口</span></h3>
            <table>
              <thead><tr><th>#</th><th>Master Product</th><th>品线</th><th className="num">用户支付金额</th><th className="num">映射店</th><th>映射完整</th></tr></thead>
              <tbody>
                {rank.map((x, i) => (
                  <tr key={i}>
                    <td>{i + 1}</td>
                    <td>{esc(x.master_product_name)}</td>
                    <td>{esc(x.product_line_name || '—')}</td>
                    <td className="num">{yuan(x.current_value)}</td>
                    <td className="num">{x.mapped_shop_count}</td>
                    <td>{x.mapping_complete ? <span className="badge green">完整</span> : <span className="badge amber">不完整</span>}</td>
                  </tr>
                ))}
                {!rank.length && <tr><td colSpan={6} className="empty">当前区间无排名数据</td></tr>}
              </tbody>
            </table>
          </div>
          <div className="card">
            <h3>主档结构</h3>
            <table>
              <thead><tr><th>编码</th><th>名称</th><th>状态</th></tr></thead>
              <tbody>
                {list.map((m, i) => (
                  <tr key={i}>
                    <td>{esc(m.master_product_code || '—')}</td>
                    <td>{esc(m.master_product_name || '—')}</td>
                    <td><span className={`badge ${m.enabled ? 'green' : 'gray'}`}>{m.enabled ? '启用' : '停用'}</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  )
}
