// F1.0.4 /materials 素材（F1.0.3 快照排名）
import { useEffect, useState } from 'react'
import type { Filters } from '../types'
import { api } from '../services/api'
import { CapabilityNotice } from '../components/CapabilityNotice'
import { yuan, esc } from '../lib/format'

interface MRank { material_name: string; material_id: string; material_evaluation: string; current_value: number }

export function MaterialsPage({ f }: { f: Filters }) {
  const [rank, setRank] = useState<MRank[]>([])
  const [err, setErr] = useState('')
  useEffect(() => {
    setErr('')
    if (!f.shop) { setRank([]); return }
    api<MRank[]>('/materials/snapshot-rank', { shop_code: f.shop, start_date: f.sd, end_date: f.ed, metric_key: 'user_pay_amount', limit: 50 })
      .then(r => setRank(r.data)).catch(e => setErr(e.message))
  }, [f.sd, f.ed, f.shop])
  return (
    <div>
      <h1>素材</h1>
      <div className="sub">素材分析快照（PERIOD_SNAPSHOT）｜ {f.sd} ～ {f.ed}</div>
      {!f.shop ? <CapabilityNotice state="SELECT_SHOP_REQUIRED" /> : (
        err ? <CapabilityNotice state="ERROR" text={err} /> : (
          <div className="card">
            <h3>素材排名（用户实际支付金额）<span className="badge green">PERIOD_SNAPSHOT</span></h3>
            <table>
              <thead><tr><th>#</th><th>素材</th><th>评估</th><th className="num">用户实际支付金额</th></tr></thead>
              <tbody>
                {rank.map((x, i) => (
                  <tr key={i}><td>{i + 1}</td><td>{esc(x.material_name || x.material_id)}</td><td>{esc(x.material_evaluation || '')}</td><td className="num">{yuan(x.current_value)}</td></tr>
                ))}
                {!rank.length && <tr><td colSpan={4} className="empty">当前周期无素材快照数据</td></tr>}
              </tbody>
            </table>
            <div className="trend-note">素材为统计周期导出（PERIOD_SNAPSHOT），不做日趋势；ROI/效率仅用源值，不推算</div>
          </div>
        )
      )}
    </div>
  )
}
