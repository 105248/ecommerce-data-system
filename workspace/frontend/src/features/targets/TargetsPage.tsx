// F1.1 /targets 目标管理：人工只维护月目标（18 行 × 6 指标）；日/周目标系统测算
// 月目标设置（可编辑）+ 周目标预览（只读）；整体=两店自动汇总（金额类），比例类单独设置
import { useEffect, useState } from 'react'
import { api } from '../../services/api'
import { CapabilityNotice } from '../../components/CapabilityNotice'
import { esc } from '../../lib/format'

const SECTIONS: Array<[number | null, string]> = [
  [null, '抖音整体'], [1, '抖音弹动官方旗舰店'], [2, '抖音弹动个人护理旗舰店'],
]
const BIZ: Array<[string, string]> = [
  ['OVERALL', '整体'], ['SELF_LIVE', '自营直播'], ['SELF_COMMERCE', '自营商品'],
  ['PARTNER_LIVE', '达人直播'], ['PARTNER_VIDEO', '达人短视频'], ['SHOWCASE', '橱窗'],
]
const METRICS: Array<[string, string, boolean]> = [
  ['transaction_amount', '成交目标(万)', false],
  ['transaction_refund_amount', '成交退款上限(万)', false],
  ['settlement_amount', '结算目标(万)', false],
  ['refund_rate', '退款率上限(%)', true],
  ['ad_spend', '投放预算(万)', false],
  ['ad_spend_rate', '投放费比上限(%)', true],
]
const AMOUNT_METRICS = new Set(['transaction_amount', 'transaction_refund_amount', 'settlement_amount', 'ad_spend'])

interface TargetRow { shop_id: number | null; business_type_code: string; metric_key: string; target_value: number | null }
interface WpRow { shop_id: number | null; business_type_code: string; metric_key: string; month_target: number | null; period_target: number | null; incomplete: boolean }

export function TargetsPage() {
  const [month, setMonth] = useState('2026-08')
  const [tab, setTab] = useState<'month' | 'week'>('month')
  const [vals, setVals] = useState<Record<string, string>>({})
  const [wpRows, setWpRows] = useState<WpRow[]>([])
  const [msg, setMsg] = useState('')
  const [err, setErr] = useState('')

  const monthKey = `${month}-01`
  const load = (m: string) => {
    api<{ rows: TargetRow[] }>('/targets', { month: `${m}-01` }).then(r => {
      const v: Record<string, string> = {}
      r.data.rows.forEach(x => {
        if (x.target_value == null) return
        const k = key(x.shop_id, x.business_type_code, x.metric_key)
        v[k] = AMOUNT_METRICS.has(x.metric_key)
          ? String(Math.round(x.target_value / 10000 * 100) / 100)
          : String(Math.round(x.target_value * 10000) / 100)
      })
      setVals(v)
    }).catch(e => setErr(e.message))
  }
  useEffect(() => { load(month); setMsg('') }, [month])
  useEffect(() => {
    if (tab === 'week') {
      api<{ rows: WpRow[] }>('/targets/weekly-preview').then(r => setWpRows(r.data.rows)).catch(() => setWpRows([]))
    }
  }, [tab])

  const key = (shop: number | null, code: string, metric: string) => `${shop ?? 'G'}|${code}|${metric}`

  function save() {
    const targets: Array<{ shop_id: number | null; business_type_code: string; metric_key: string; target_value: number | null }> = []
    SECTIONS.forEach(([shop]) => BIZ.forEach(([code]) => METRICS.forEach(([metric]) => {
      const k = key(shop, code, metric)
      const raw = (vals[k] || '').trim()
      if (raw === '') { return }  // 空=未设置目标，不写入（避免 NULL 占位行）
      const num = parseFloat(raw)
      if (Number.isNaN(num)) return
      targets.push({ shop_id: shop, business_type_code: code, metric_key: metric,
        target_value: AMOUNT_METRICS.has(metric) ? Math.round(num * 10000) : num / 100 })
    })))
    api<{ updated: number }>('/targets', {}, 'PUT', { month: monthKey, targets })
      .then(() => { setMsg(`已保存（${month} 月目标）`); setErr(''); load(month) })
      .catch(e => setErr(e.message))
  }

  function copyLastMonth() {
    const y = parseInt(month.slice(0, 4), 10), m = parseInt(month.slice(5, 7), 10)
    const lm = m === 1 ? `${y - 1}-12` : `${y}-${String(m - 1).padStart(2, '0')}`
    api<{ rows: TargetRow[] }>('/targets', { month: `${lm}-01` }).then(r => {
      const v: Record<string, string> = {}
      r.data.rows.forEach(x => {
        if (x.target_value == null) return
        const k = key(x.shop_id, x.business_type_code, x.metric_key)
        v[k] = AMOUNT_METRICS.has(x.metric_key)
          ? String(Math.round(x.target_value / 10000 * 100) / 100)
          : String(Math.round(x.target_value * 10000) / 100)
      })
      setVals(v)
      setMsg(`已复制 ${lm} 月目标到 ${month} 月（未保存，请点保存生效）`)
    }).catch(e => setErr(e.message))
  }

  return (
    <div>
      <h1>目标管理</h1>
      <div className="sub">人工只维护月目标；日报/周报目标由系统按"月目标÷当月自然天×期间天数"自动测算（退款率/投放费比不按天折算）</div>
      <div style={{ display: 'flex', gap: 10, alignItems: 'center', margin: '10px 0', flexWrap: 'wrap' }}>
        <span style={{ fontSize: 13, color: '#374151' }}>月份：</span>
        <input type="month" value={month} onChange={e => setMonth(e.target.value)} style={{ padding: '4px 8px', borderRadius: 6, border: '1px solid #d1d5db' }} />
        <button onClick={copyLastMonth} style={{ padding: '5px 12px', borderRadius: 6, border: '1px solid #d1d5db', background: '#fff', cursor: 'pointer', fontSize: 13 }}>复制上月目标</button>
        <button onClick={save} style={{ padding: '5px 16px', borderRadius: 6, border: 'none', background: '#2563eb', color: '#fff', cursor: 'pointer', fontSize: 13 }}>保存</button>
        <div style={{ display: 'flex', gap: 6 }}>
          {([['month', '月目标设置'], ['week', '周目标预览']] as Array<[string, string]>).map(([k, l]) => (
            <button key={k} onClick={() => setTab(k as 'month' | 'week')}
              style={{ padding: '5px 12px', borderRadius: 6, border: '1px solid #d1d5db', cursor: 'pointer',
                       background: tab === k ? '#eef2ff' : '#fff', color: tab === k ? '#1e40af' : '#374151', fontSize: 13 }}>
              {l}
            </button>
          ))}
        </div>
        {msg && <span style={{ fontSize: 12, color: '#16a34a' }}>{esc(msg)}</span>}
      </div>
      {err && <CapabilityNotice state="ERROR" text={err} />}
      {tab === 'month' ? (
        <div>
          {SECTIONS.map(([shop, secName]) => (
            <div className="card" key={String(shop)} style={{ marginBottom: 12, overflowX: 'auto' }}>
              <h3 style={{ fontSize: 14, marginBottom: 6 }}>{esc(secName)}</h3>
              <table style={{ minWidth: 900 }}>
                <thead>
                  <tr>
                    <th style={{ width: 90 }}>经营项目</th>
                    {METRICS.map(([metric, label]) => <th key={metric} className="num" style={{ fontSize: 12 }}>{label}</th>)}
                  </tr>
                </thead>
                <tbody>
                  {BIZ.map(([code, name]) => (
                    <tr key={code} style={code === 'OVERALL' ? { background: '#f9fafb' } : undefined}>
                      <td style={code === 'OVERALL' ? { fontWeight: 600 } : undefined}>{name}</td>
                      {METRICS.map(([metric, , isRate]) => (
                        <td key={metric} className="num">
                          <input
                            value={vals[key(shop, code, metric)] || ''}
                            placeholder={isRate ? '≤18' : '1200'}
                            onChange={e => setVals({ ...vals, [key(shop, code, metric)]: e.target.value })}
                            style={{ width: 90, padding: '4px 6px', borderRadius: 6, border: '1px solid #d1d5db', textAlign: 'right', fontSize: 13 }}
                          />
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
              <div style={{ fontSize: 11, color: '#9ca3af', marginTop: 4 }}>
                金额单位：万（保存时换算为元）；比例单位：%（保存时换算为 0-1）。空=未设置目标（非 0）。整体金额类目标自动汇总两店（可不填）。
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="card">
          <h3 style={{ fontSize: 14, marginBottom: 6 }}>周目标预览（只读，不单独维护）</h3>
          {wpRows.length === 0 ? <CapabilityNotice state="NO_DATA" text="当前无已设置目标" /> : (
            <table>
              <thead><tr><th>区块</th><th>经营项目</th><th>指标</th><th className="num">月目标</th><th className="num">测算周目标</th><th>状态</th></tr></thead>
              <tbody>
                {wpRows.map((r, i) => (
                  <tr key={i}>
                    <td>{r.shop_id == null ? '抖音整体' : r.shop_id === 1 ? '抖音弹动官方旗舰店' : '抖音弹动个人护理旗舰店'}</td>
                    <td>{esc(BIZ.find(([c]) => c === r.business_type_code)?.[1] || r.business_type_code)}</td>
                    <td>{esc(METRICS.find(([m]) => m === r.metric_key)?.[1] || r.metric_key)}</td>
                    <td className="num">{AMOUNT_METRICS.has(r.metric_key) ? `${(r.month_target ?? 0) / 10000}万` : `${((r.month_target ?? 0) * 100).toFixed(1)}%`}</td>
                    <td className="num">{r.period_target != null ? (AMOUNT_METRICS.has(r.metric_key) ? `${(r.period_target / 10000).toFixed(1)}万` : `${(r.period_target * 100).toFixed(1)}%`) : '—'}</td>
                    <td>{r.incomplete ? <span style={{ color: '#d97706' }}>本周目标不完整（下月目标未设置）</span> : r.period_target == null ? '未设置目标' : ''}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
    </div>
  )
}
