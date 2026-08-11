// F1.1 /data-center 数据中心：数据覆盖概览（店铺数据区间 + 智能层状态）
import { useEffect, useState } from 'react'
import { api } from '../../services/api'

interface CovRow { shop_name: string; min_date: string; max_date: string; day_count: number; row_count: number }
interface Intel { latest_fact_date: string | null; capabilities: Record<string, { latest_generated_date: string | null; status: string }>; intelligence_status: string }

export function DataCenterPage() {
  const [cov, setCov] = useState<CovRow[]>([])
  const [intel, setIntel] = useState<Intel | null>(null)
  useEffect(() => {
    api<CovRow[]>('/data-status').then(r => setCov(r.data)).catch(() => {})
    api<Intel>('/intelligence-status').then(r => setIntel(r.data)).catch(() => {})
  }, [])
  return (
    <div>
      <h1>数据中心</h1>
      <div className="sub">经营数据覆盖（原始数据自动导入 → PostgreSQL core → mart 正式计算）</div>
      <div className="card">
        <h3 style={{ fontSize: 14, marginBottom: 6 }}>店铺数据覆盖</h3>
        <table>
          <thead><tr><th>店铺</th><th className="num">最早日期</th><th className="num">最新日期</th><th className="num">天数</th><th className="num">行数</th></tr></thead>
          <tbody>
            {cov.map((r, i) => (
              <tr key={i}>
                <td>{r.shop_name}</td><td className="num">{r.min_date}</td><td className="num">{r.max_date}</td>
                <td className="num">{r.day_count}</td><td className="num">{r.row_count.toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="card">
        <h3 style={{ fontSize: 14, marginBottom: 6 }}>智能分析状态</h3>
        {intel ? (
          <table>
            <thead><tr><th>能力</th><th className="num">最新生成日期</th><th>状态</th></tr></thead>
            <tbody>
              {Object.entries(intel.capabilities || {}).map(([k, v]) => (
                <tr key={k}>
                  <td>{k === 'anomaly' ? '异常检测' : k === 'diagnosis' ? '问题诊断' : k === 'opportunity' ? '机会发现' : '经营优先级'}</td>
                  <td className="num">{v.latest_generated_date || '—'}</td>
                  <td><span className={`badge ${v.status === 'FRESH' ? 'green' : 'red'}`}>{v.status === 'FRESH' ? 'FRESH' : 'STALE'}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : <div className="empty">加载中…</div>}
        <div className="trend-note">最新经营数据日：{intel?.latest_fact_date || '—'} ｜ 智能层 STALE 时目标系统仍正常（目标判定独立于智能层）</div>
      </div>
    </div>
  )
}
