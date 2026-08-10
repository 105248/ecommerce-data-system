// F1.0.4 正式类型定义（Page→API→DB 契约类型）

export type CapabilityState =
  | 'READY' | 'NO_DATA' | 'PARTIAL_DATA' | 'COVERAGE_INCOMPLETE' | 'MAPPING_INCOMPLETE'
  | 'UNSUPPORTED_METRIC' | 'UNSUPPORTED_DIMENSION_COMBINATION' | 'SOURCE_NOT_AVAILABLE'
  | 'REFRESH_STALE' | 'SELECT_SHOP_REQUIRED' | 'ERROR'

export interface ApiResponse<T> {
  success: boolean
  data: T
  meta?: Record<string, unknown>
  error?: { code: string; message: string }
}

export interface BusinessSummary {
  transaction_amount: number | null
  user_pay_amount: number | null
  refund_amount_pay_time: number | null
  transaction_refund_amount_pay_time: number | null
  settlement_amount: number | null
  refund_rate: number | null
  ad_spend_shop_promoted: number | null
  ad_spend_shop_bound: number | null
  ad_spend_rate_net_refund_shop_bound: number | null
  [k: string]: number | string | null | undefined
}

export interface TrendPoint { date: string; metric_value: number | null }

export interface ShopContributionRow {
  shop_code?: string
  shop_name: string
  current_value: number
  previous_value: number | null
  contribution: number
  contribution_change: number | null
  absolute_change: number | null
}

export interface RiskRow {
  entity_name: string
  domain_key: string
  severity: string
  anomaly_type: string
  anomaly_name_cn?: string
  current_value: number | null
  absolute_change: number | null
  consecutive_day_count: number
  coverage_complete: boolean
  business_impact?: number | null
  risk_priority_score?: number | null
  risk_level?: string | null
  [k: string]: unknown
}

export interface OpportunityRow {
  entity_name: string
  domain_key: string
  opportunity_code: string
  opportunity_name_cn?: string
  opportunity_score: number
  opportunity_level: string
  current_value: number | null
  relative_change: number | null
  benchmark_p50: number | null
  available_weight: number | null
  opportunity_priority_score?: number | null
  business_impact?: number | null
  [k: string]: unknown
}

export interface IntelligenceStatus {
  latest_fact_date: string | null
  latest_anomaly_generated_date: string | null
  latest_diagnosis_generated_date: string | null
  latest_opportunity_generated_date: string | null
  latest_priority_generated_date: string | null
  last_run_at: string | null
  intelligence_status: 'FRESH' | 'STALE'
}

export interface Filters {
  shop: string
  shopName: string
  sd: string
  ed: string
  scope: string
  preset: string
  today?: string
}

export interface PageMeta {
  title: string
  supportsShop: boolean
  supportsScope: boolean
}

export const SCOPE_LIST = ['全店', '自营', '合作', '商品卡', '短视频', '直播', '图文', '其他',
  '自营商品卡', '合作商品卡', '自营短视频', '合作短视频', '自营直播', '合作直播',
  '自营图文', '合作图文', '自营其他', '合作其他']

export const PRESET_CN: Record<string, string> = {
  today: '今天', yesterday: '昨天', last7days: '近7天', last14days: '近14天',
  last30days: '近30天', this_month: '本月', last_month: '上月', custom: '自定义',
}
