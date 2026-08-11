// F1.1 /progress 经营进度（核心主入口）：日报/周报/月报共用一套结构
// 18 行固定经营报表（3 区块 × 6 经营类型）× 6 指标；成交金额进度条；其他指标仅异常才提示
// 全部数值/进度/告警来自 mart.get_operating_progress（前端零计算）
import { useEffect, useState } from 'react'
import type { Filters } from '../../types'
import { api } from '../../services/api'
import { CapabilityNotice } from '../../components/CapabilityNotice'
import { yuan, pct, esc } from '../../lib/format'

interface OpRow {
  section_name: string
  business_type: string
  business_type_code: string
  period_start: string
  period_end: string
  coverage_complete: boolean
  coverage_note: string | null
  transaction_amount: number | null
  transaction_month_target: number | null
  transaction_period_target: number | null
  transaction_completion_rate: number | null
  transaction_time_progress: number | null
  transaction_progress_gap: number | null
  transaction_refund_amount: number | null
  transaction_refund_alert: string | null
  settlement_amount: number | null
  settlement_alert: string | null
  refund_rate: number | null
  refund_rate_alert: string | null
  ad_spend: number | null
  ad_spend_alert: string | null
  ad_spend_rate: number | null
  ad_spend_rate_alert: string | null
}

const SECTIONS = ['抖音整体', '抖音弹动官方旗舰店', '抖音弹动个人护理旗舰店'] as const
const TABS: Array<[string, string]> = [['daily', '日报'], ['weekly', '周报'], ['monthly', '月报']]
const ALERT_FIELDS: Array<[string, keyof OpRow]> = [
  ['settlement_alert', 'settlement_alert'], ['transaction_refund_alert', 'transaction_refund_alert'],
  ['ad_spend_alert', 'ad_spend_alert'], ['refund_rate_alert', 'refund_rate_alert'], ['ad_spend_rate_alert', 'ad_spend_rate_alert'],
]

export function ProgressPage({ f, h }: { f: Filters; h: { changePreset: (k: string) => void } }) {
  const [pt, setPt] = useState<'daily' | 'weekly' | 'monthly'>('daily')
  const [rows, setRows] = useState<OpRow[]>([])
  const [err, setErr] = useState('')
  const [fact, setFact] = useState<string>('')

  useEffect(() => {
    let ignore = false
    setErr('')
    api<{ rows: OpRow[]; anchor_date: string | null }>('/operating-progress', { period_type: pt })
      .then(r => {
        if (ignore) return
        setRows(r.data.rows || [])
        if (r.data.anchor_date) setFact(r.data.anchor_date)
      }).catch(e => { if (!ignore) setErr(e.message) })
    return () => { ignore = true }
  }, [pt])

  // 数据截至（后端 anchor 未回传时用行内 period_end）
  const anchor = fact || (rows[0]?.period_end || '')
  const coverage = rows.length > 0 ? rows[0].coverage_complete : true
  const coverageNote = rows[0]?.coverage_note || null
  const periodLabel = rows.length > 0 ? `${rows[0].period_start} ～ ${rows[0].period_end}` : ''

  // 未达标统计：成交进度落后 + 其他 5 指标告警（行去重）
  const issues = new Set<string>()
  rows.forEach(r => {
    if (r.transaction_progress_gap != null && r.transaction_progress_gap < 0) issues.add(r.section_name + r.business_type)
    ALERT_FIELDS.forEach(([, k]) => { if (r[k as keyof OpRow] != null) issues.add(r.section_name + r.business_type) })
  })

  function exportCsv() {
    const head = ['区块', '经营类型', '成交金额', '成交退款金额', '结算金额', '退款率', '投放消耗', '投放费比']
    const lines = rows.map(r => [r.section_name, r.business_type,
      r.transaction_amount ?? '', r.transaction_refund_amount ?? '', r.settlement_amount ?? '',
      r.refund_rate != null ? (r.refund_rate * 100).toFixed(2) + '%' : '',
      r.ad_spend ?? '', r.ad_spend_rate != null ? (r.ad_spend_rate * 100).toFixed(2) + '%' : '',
    ].join(','))
    const blob = new Blob(['\ufeff' + head.join(',') + '\n' + lines.join('\n')], { type: 'text/csv;charset=utf-8' })
    const a = document.createElement('a')
    a.href = URL.createObjectURL(blob)
    a.download = `经营进度_${pt}_${anchor || ''}.csv`
    a.click()
    URL.revokeObjectURL(a.href)
  }

  return (
    <div>
      <h1>经营进度</h1>
      <div style={{ display: 'flex', gap: 8, margin: '10px 0', alignItems: 'center' }}>
        {TABS.map(([k, label]) => (
          <button key={k} onClick={() => setPt(k as typeof pt)}
            style={{ padding: '6px 18px', borderRadius: 8, border: '1px solid #d1d5db', cursor: 'pointer',
                     background: pt === k ? '#2563eb' : '#fff', color: pt === k ? '#fff' : '#374151', fontSize: 13 }}>
            {label}
          </button>
        ))}
        <span style={{ fontSize: 12, color: '#6b7280', marginLeft: 8 }}>
          {periodLabel && `日期：${periodLabel}`} ｜ 数据截至：<b>{anchor || '—'}</b>
          {rows.length > 0 && (coverage ? ' ｜ 数据完整度：完整' : ` ｜ 数据完整度：不完整（${esc(coverageNote || '')}）`)}
        </span>
        <button onClick={exportCsv} style={{ marginLeft: 'auto', padding: '5px 14px', borderRadius: 8, border: '1px solid #d1d5db', background: '#fff', cursor: 'pointer', fontSize: 13 }}>
          导出
        </button>
      </div>
      {!coverage && rows.length > 0 && (
        <CapabilityNotice state="COVERAGE_INCOMPLETE" text={`数据覆盖不完整（${esc(coverageNote || '')}），暂不判断目标达成状态（防漏数据假预警）`} />
      )}
      {issues.size > 0 && (
        <div style={{ padding: '9px 14px', borderRadius: 8, background: '#fef3c7', border: '1px solid #fde68a', color: '#92400e', fontSize: 13, marginBottom: 10 }}>
          ⚠ 当前有 <b>{issues.size}</b> 项经营未达到要求 <a href="#/attention" style={{ fontWeight: 600 }}>[查看]</a>
        </div>
      )}
      {err ? <CapabilityNotice state="ERROR" text={err} /> : rows.length === 0 ? (
        <CapabilityNotice state="NO_DATA" text="当前期间无经营数据" />
      ) : (
        SECTIONS.map(sec => {
          const secRows = rows.filter(r => r.section_name === sec)
          if (!secRows.length) return null
          return (
            <div className="card" key={sec} style={{ marginBottom: 14 }}>
              <h3 style={{ fontSize: 15, marginBottom: 6 }}>{esc(sec)}</h3>
              <table>
                <thead>
                  <tr>
                    <th style={{ width: 90 }}>经营类型</th>
                    <th className="num">成交金额</th>
                    <th className="num">成交退款金额</th>
                    <th className="num">结算金额</th>
                    <th className="num">退款率</th>
                    <th className="num">投放消耗</th>
                    <th className="num">投放费比</th>
                  </tr>
                </thead>
                <tbody>
                  {secRows.map((r, i) => (
                    <tr key={i} style={r.business_type === '整体' ? { background: '#f9fafb' } : undefined}>
                      <td style={r.business_type === '整体' ? { fontWeight: 600 } : undefined}>{esc(r.business_type)}</td>
                      <td className="num">
                        <TxnCell r={r} pt={pt} />
                      </td>
                      <td className="num">
                        <Cell value={r.transaction_refund_amount != null ? yuan(r.transaction_refund_amount) : '—'} alert={r.transaction_refund_alert} />
                      </td>
                      <td className="num">
                        <Cell value={r.settlement_amount != null ? yuan(r.settlement_amount) : '—'} alert={r.settlement_alert} />
                      </td>
                      <td className="num">
                        <Cell value={r.refund_rate != null ? pct(r.refund_rate) : '—'} alert={r.refund_rate_alert} />
                      </td>
                      <td className="num">
                        <Cell value={r.ad_spend != null ? yuan(r.ad_spend) : '—'} alert={r.ad_spend_alert} />
                      </td>
                      <td className="num">
                        <Cell value={r.ad_spend_rate != null ? pct(r.ad_spend_rate) : '—'} alert={r.ad_spend_rate_alert} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )
        })
      )}
    </div>
  )
}

// 普通单元格：仅异常才显示 ⚠（不显示达标/✓/目标值）
function Cell({ value, alert }: { value: string; alert: string | null }) {
  return (
    <div>
      <div>{value}</div>
      {alert && <div style={{ color: '#dc2626', fontSize: 11, fontWeight: 500 }}>⚠ {esc(alert)}</div>}
    </div>
  )
}

// 成交金额格：实际 + 测算目标 + 进度条 + 时间进度 + 领先/落后
function TxnCell({ r, pt }: { r: OpRow; pt: string }) {
  const rate = r.transaction_completion_rate
  const gap = r.transaction_progress_gap
  const pctW = rate != null ? Math.max(0, Math.min(100, rate * 100)) : 0
  return (
    <div style={{ minWidth: 130 }}>
      <div>
        <b>{r.transaction_amount != null ? yuan(r.transaction_amount) : '—'}</b>
        {r.transaction_period_target != null && (
          <span style={{ color: '#6b7280', fontSize: 11, marginLeft: 6 }}>
            目标 {pt === 'monthly' ? (r.transaction_month_target != null ? yuan(r.transaction_month_target) : yuan(r.transaction_period_target)) : yuan(r.transaction_period_target)}
          </span>
        )}
      </div>
      {rate != null && (
        <>
          <div style={{ height: 6, background: '#e5e7eb', borderRadius: 3, margin: '4px 0', overflow: 'hidden' }}>
            <div style={{ width: `${pctW}%`, height: '100%', background: gap != null && gap < 0 ? '#dc2626' : '#2563eb' }} />
          </div>
          <div style={{ fontSize: 11, color: '#6b7280' }}>
            完成 {(rate * 100).toFixed(1)}%
            {r.transaction_time_progress != null && <> ｜ 时间进度 {(r.transaction_time_progress * 100).toFixed(1)}%</>}
            {gap != null && (
              gap >= 0
                ? <span style={{ color: '#16a34a', marginLeft: 4 }}>领先 {(gap * 100).toFixed(1)}%</span>
                : <span style={{ color: '#dc2626', marginLeft: 4 }}>落后 {(-gap * 100).toFixed(1)}%</span>
            )}
          </div>
        </>
      )}
      {r.transaction_period_target == null && r.transaction_amount != null && (
        <div style={{ fontSize: 11, color: '#6b7280' }}>未设置目标</div>
      )}
    </div>
  )
}
