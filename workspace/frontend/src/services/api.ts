// F1.0.4 正式 API Service 层（Web → Backend API → 白名单函数；前端零经营计算）
import type { ApiResponse, BusinessSummary, TrendPoint, ShopContributionRow, RiskRow, OpportunityRow, IntelligenceStatus } from '../types'

const BASE = '/api/v1'

export async function api<T>(path: string, params: Record<string, string | number | null | undefined> = {}): Promise<ApiResponse<T>> {
  const q = new URLSearchParams()
  for (const [k, v] of Object.entries(params)) {
    if (v !== null && v !== undefined && v !== '') q.set(k, String(v))
  }
  const url = `${BASE}${path}${q.toString() ? '?' + q.toString() : ''}`
  const res = await fetch(url)
  const json = await res.json() as ApiResponse<T>
  if (!json.success) {
    const err = new Error(json.error?.message || json.error?.code || 'API Error')
    ;(err as Error & { code?: string }).code = json.error?.code
    throw err
  }
  return json
}

// ===== 经营摘要 =====
export function getSummary(f: { shop?: string; sd: string; ed: string; scope: string }) {
  return api<BusinessSummary>('/business/summary', {
    shop_code: f.shop, start_date: f.sd, end_date: f.ed, scope_key: f.scope,
  })
}

// ===== 趋势（单次查询，非 N 次循环） =====
export function getTrend(f: { shop?: string; sd: string; ed: string; scope: string }, metricKey: string) {
  return api<TrendPoint[]>('/business/trend', {
    shop_code: f.shop, start_date: f.sd, end_date: f.ed, scope_key: f.scope, metric_key: metricKey,
  })
}

export function getShopContribution(f: { sd: string; ed: string; scope: string }) {
  return api<ShopContributionRow[]>('/business/shop-contribution', {
    start_date: f.sd, end_date: f.ed, scope_key: f.scope,
  })
}

export function getRiskTop(f: { sd: string; ed: string }, limit = 5) {
  return api<RiskRow[]>('/priorities/risks', { start_date: f.sd, end_date: f.ed, limit })
}
export function getOpportunityTop(f: { sd: string; ed: string }, limit = 5) {
  return api<OpportunityRow[]>('/priorities/opportunities', { start_date: f.sd, end_date: f.ed, limit })
}
export function getIntelligenceStatus() {
  return api<IntelligenceStatus>('/intelligence-status')
}
export function getDataStatus(shopCode?: string) {
  return api<Array<{ shop_name: string; min_date: string; max_date: string; day_count: number }>>('/data-status', {
    shop_code: shopCode,
  })
}
