// F1.1 V2.0 正式前端入口：经营进度为核心，业务分析精简，待关注/目标管理/数据中心/问数据
// 旧业务分析页（商品/商品卡/短视频/投放/退款/直播/素材/搜索/智能经营/风险/诊断/机会）→ UI_HIDDEN，能力保留
import React from 'react'
import ReactDOM from 'react-dom/client'
import { AppShell } from './components/AppShell'
import { ProgressPage } from './features/progress/ProgressPage'
import { AttentionPage } from './features/attention/AttentionPage'
import { TargetsPage } from './features/targets/TargetsPage'
import { DataCenterPage } from './features/data/DataCenterPage'
import { AskPage } from './features/ask/AskPage'
import { ProductLinesPage } from './features/product-lines/ProductLinesPage'
import { MasterProductsPage } from './features/master-products/MasterProductsPage'
import { AccountsPage } from './features/pages'
import type { Filters } from './types'

type Helpers = { changePreset: (k: string) => void }

function Router({ f, h }: { f: Filters; h: Helpers }) {
  const route = location.hash.slice(1) || '/progress'
  switch (route) {
    case '/progress': return <ProgressPage f={f} h={h} />
    case '/attention': return <AttentionPage />
    case '/targets': return <TargetsPage />
    case '/data-center': return <DataCenterPage />
    case '/ask': return <AskPage />
    case '/product-lines': return <ProductLinesPage f={f} />
    case '/master-products': return <MasterProductsPage f={f} />
    case '/accounts': return <AccountsPage f={f} />
    // UI_HIDDEN 旧路由安全回退经营进度（能力保留，智能体可查）
    default: return <ProgressPage f={f} h={h} />
  }
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <AppShell>
      {(f, h) => <Router f={f} h={h} />}
    </AppShell>
  </React.StrictMode>,
)
