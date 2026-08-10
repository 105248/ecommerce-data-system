// F1.0.4 前端工具：纯 UI 格式化（禁止 format 结果参与业务计算）+ 能力状态文案

export function fmt(v: number | null | undefined): string {
  if (v === null || v === undefined || Number.isNaN(v)) return '—'
  return new Intl.NumberFormat('zh-CN', { maximumFractionDigits: 2 }).format(v)
}

export function yuan(v: number | null | undefined): string {
  if (v === null || v === undefined || Number.isNaN(v)) return '—'
  return '¥' + fmt(v)
}

export function pct(v: number | null | undefined): string {
  if (v === null || v === undefined || Number.isNaN(v)) return '—'
  return (v * 100).toFixed(2) + '%'
}

export function esc(s: unknown): string {
  if (s === null || s === undefined) return ''
  return String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!))
}

export const CAPABILITY_CN: Record<string, string> = {
  NO_DATA: '当前区间无数据',
  PARTIAL_DATA: '部分数据可用',
  COVERAGE_INCOMPLETE: '数据覆盖不完整',
  MAPPING_INCOMPLETE: '映射不完整',
  UNSUPPORTED_METRIC: '当前数据粒度不支持该指标',
  UNSUPPORTED_DIMENSION_COMBINATION: '不支持该维度组合',
  SOURCE_NOT_AVAILABLE: '当前没有对应源数据',
  REFRESH_STALE: '最新经营数据已更新，智能分析尚未刷新',
  SELECT_SHOP_REQUIRED: '该能力为店铺级，请选择店铺',
  ERROR: '系统异常',
}

// 标题随查询区间变化（指令八）
export function pageTitleForToday(sd: string, ed: string, today: string): string {
  if (sd === ed && sd === today) return '今日经营'
  if (sd === ed) return '单日经营'
  return '经营概览'
}
