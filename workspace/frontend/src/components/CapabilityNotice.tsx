// F1.0.4 共享组件：CapabilityNotice（11 态统一）
import type { CapabilityState } from '../types'
import { CAPABILITY_CN, esc } from '../lib/format'

export function CapabilityNotice({ state, text }: { state: CapabilityState; text?: string }) {
  if (state === 'NO_DATA') {
    return <div className="empty">{esc(text || '当前区间无数据')}</div>
  }
  if (state === 'SOURCE_NOT_AVAILABLE' || state === 'UNSUPPORTED_METRIC' || state === 'REFRESH_STALE' ||
      state === 'SELECT_SHOP_REQUIRED' || state === 'UNSUPPORTED_DIMENSION_COMBINATION' ||
      state === 'COVERAGE_INCOMPLETE' || state === 'MAPPING_INCOMPLETE' || state === 'PARTIAL_DATA') {
    return (
      <div className="notice amber">
        <b>{state}</b> ｜ {CAPABILITY_CN[state]}{text ? `：${esc(text)}` : ''}
      </div>
    )
  }
  return <div className="err">{esc(text || CAPABILITY_CN[state] || '未知状态')}</div>
}

export function ErrBlock({ msg, fallback, cols }: { msg: string; fallback?: string; cols?: number }) {
  return <div className="err">{esc(msg)}{fallback ? `（${esc(fallback)}）` : ''}</div>
}
