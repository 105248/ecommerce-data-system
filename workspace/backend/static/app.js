// ============================================================================
// F1.0 抖音智能经营工作台 SPA（全页面业务化整改版）
// 架构：公共 AppShell（Sidebar/GlobalFilters/StatusBar）+ 18 个独立业务路由
// 数据路径：Web → Backend API → 正式数据库接口（mart/meta 白名单），前端零经营计算
// ============================================================================
const $ = s => document.querySelector(s);
const fmt = n => n == null ? '—' : Number(n).toLocaleString('zh-CN', {maximumFractionDigits: 2});
const pct = n => n == null ? '—' : (Number(n) * 100).toFixed(2) + '%';
const yuan = n => n == null ? '—' : '¥' + fmt(n);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const iso = d => d.toISOString().slice(0,10);
const addDay = (dt, n) => { const x = new Date(dt + 'T00:00:00'); x.setDate(x.getDate() + n); return iso(x); };
const prevMonth = mx => { const d = new Date(mx + 'T00:00:00'); const p = new Date(d.getFullYear(), d.getMonth()-1, 1); const pe = new Date(d.getFullYear(), d.getMonth(), 0); return [iso(p), iso(pe)]; };

// ============================================================================
// 全局状态（Single Source of Truth）
// 日期只允许一种状态：preset ∈ {today,yesterday,last7days,last14days,last30days,this_month,last_month,custom}
// preset 与 sd/ed 永远一致：改 preset → 重算 sd/ed；改 sd/ed → preset 自动转 custom
// ============================================================================
let MX = null; // 系统最新入库日期（来自 /data-status，独立于查询区间）
const PRESET_CN = {today:'今天', yesterday:'昨天', last7days:'近7天', last14days:'近14天', last30days:'近30天', this_month:'本月', last_month:'上月', custom:'自定义'};
const G = {
  shop: localStorage.getItem('g.shop') || '',
  scope: localStorage.getItem('g.scope') || '全店',
  page: location.hash.slice(1) || '/today',
  preset: 'custom',
  sd: localStorage.getItem('g.sd') || '',
  ed: localStorage.getItem('g.ed') || '',
};
function saveG(){ ['shop','scope','sd','ed'].forEach(k=>localStorage.setItem('g.'+k, G[k])); G.preset = derivePreset(G.sd, G.ed); }

function applyPreset(preset){
  if (!MX) return;
  if (preset === 'today')       { G.sd = MX; G.ed = MX; }
  else if (preset === 'yesterday') { const y = addDay(MX,-1); G.sd = y; G.ed = y; }
  else if (preset === 'last7days') { G.sd = addDay(MX,-6); G.ed = MX; }
  else if (preset === 'last14days'){ G.sd = addDay(MX,-13); G.ed = MX; }
  else if (preset === 'last30days'){ G.sd = addDay(MX,-29); G.ed = MX; }
  else if (preset === 'this_month'){ G.sd = MX.slice(0,8) + '01'; G.ed = MX; }
  else if (preset === 'last_month'){ const pm = prevMonth(MX); G.sd = pm[0]; G.ed = pm[1]; }
  G.preset = preset;
}
function derivePreset(sd, ed){
  if (!MX || !sd || !ed) return 'custom';
  if (sd === ed && sd === MX) return 'today';
  if (sd === ed && ed === addDay(MX,-1)) return 'yesterday';
  if (sd === addDay(MX,-6) && ed === MX) return 'last7days';
  if (sd === addDay(MX,-13) && ed === MX) return 'last14days';
  if (sd === addDay(MX,-29) && ed === MX) return 'last30days';
  if (sd === MX.slice(0,8)+'01' && ed === MX) return 'this_month';
  const pm = prevMonth(MX);
  if (sd === pm[0] && ed === pm[1]) return 'last_month';
  return 'custom';
}

// ============================================================================
// 菜单（业务路由；/smart-operation 为新智能经营总入口）
// ============================================================================
const MENU = [
  ['g0','核心',''], ['/today','今日经营'], ['/store','店铺'], ['/priorities','经营优先级'],
  ['g1','业务分析',''], ['/product-lines','品线'], ['/master-products','Master Product'], ['/products','商品'],
  ['/product-card','商品卡'], ['/advertising','投放'], ['/refund','退款'], ['/accounts','达人/账号'],
  ['/live','直播'], ['/video','短视频'], ['/search','搜索'], ['/materials','素材'],
  ['g2','决策层',''], ['/smart-operation','智能经营'], ['/risks','风险中心'], ['/diagnosis','问题诊断'], ['/opportunities','增长机会'],
  ['g3','平台',''], ['/data-center','数据中心'], ['/system-status','系统状态'], ['/data-status','数据状态'],
];

// ============================================================================
// Filter Capability Matrix：每个页面独立声明支持哪些筛选
// supports_shop / supports_date / supports_scope（平台固定 douyin 全站显示）
// ============================================================================
const PAGE_META = {
  '/today':           {title:'经营概览', supports_shop:true,  supports_scope:true},
  '/store':           {title:'店铺经营', supports_shop:false, supports_scope:true},
  '/priorities':      {title:'经营优先级', supports_shop:false, supports_scope:false},
  '/product-lines':   {title:'品线分析', supports_shop:false, supports_scope:false},
  '/master-products': {title:'Master Product', supports_shop:false, supports_scope:false},
  '/products':        {title:'商品分析', supports_shop:true,  supports_scope:false},
  '/product-card':    {title:'商品卡经营', supports_shop:true, supports_scope:false},
  '/advertising':     {title:'投放经营', supports_shop:true,  supports_scope:true},
  '/refund':          {title:'退款分析', supports_shop:true,  supports_scope:true},
  '/accounts':        {title:'达人 / 账号', supports_shop:true, supports_scope:false},
  '/live':            {title:'直播经营', supports_shop:true,  supports_scope:false},
  '/video':           {title:'短视频经营', supports_shop:true, supports_scope:false},
  '/search':          {title:'搜索', supports_shop:false, supports_scope:false},
  '/materials':       {title:'素材', supports_shop:false, supports_scope:false},
  '/smart-operation': {title:'智能经营', supports_shop:false, supports_scope:false},
  '/risks':           {title:'风险中心', supports_shop:false, supports_scope:false},
  '/diagnosis':       {title:'问题诊断', supports_shop:false, supports_scope:false},
  '/opportunities':   {title:'增长机会', supports_shop:false, supports_scope:false},
  '/data-center':     {title:'数据中心', supports_shop:false, supports_scope:false},
  '/system-status':   {title:'系统状态', supports_shop:false, supports_scope:false},
  '/data-status':     {title:'数据状态', supports_shop:false, supports_scope:false},
};
const SCOPES = ['全店','自营','合作','商品卡','直播','短视频','图文','其他','自营直播','合作直播','自营短视频','合作短视频','自营商品卡','合作商品卡','自营图文','合作图文','自营其他','合作其他'];
const SHOP_NAMES = {DY_DANDONG_OFFICIAL:'弹动官方旗舰店', DY_GERENHULI_OFFICIAL:'弹动个人护理旗舰店'};

async function api(path, params){
  const q = params ? '?' + new URLSearchParams(params) : '';
  const r = await fetch('/api/v1' + path + q);
  const j = await r.json();
  if (!j.success) { const e = new Error(j.error?.message || j.error?.code); e.code = j.error?.code; throw e; }
  return j;
}

// ============================================================================
// 共享组件（共享 UI 组件 ≠ 共享业务查询）
// ============================================================================
// goodWhen: 'high' 涨=好绿跌=坏红；'low'（退款率/费比等）跌=好绿涨=坏红
function MetricCard(label, cur, opts){
  // QA 重建(P1-07)：环比 chg 直接来自正式接口（compare.absolute_change / percentage_point_change），前端不做 cur-prev
  opts = opts || {};
  const v = opts.isRate ? pct(cur) : yuan(cur);
  if (opts.chg == null || cur == null) return `<div class="kpi"><div class="l">${label}</div><div class="v">${v}</div></div>`;
  const d = opts.chg;
  const up = d > (opts.isRate ? 0.0001 : 0.0001), dn = d < -(opts.isRate ? 0.0001 : 0.0001);
  const good = opts.goodWhen === 'low' ? dn : up;
  const cls = up || dn ? (good ? 'good' : 'bad') : 'flat';
  const txt = opts.isRate ? (d >= 0 ? '+' : '') + (d*100).toFixed(2) + ' pp' : (d >= 0 ? '+' : '') + fmt(d);
  return `<div class="kpi"><div class="l">${label}</div><div class="v">${v}</div><div class="c ${cls}">较上期 ${txt}</div></div>`;
}
function covBadge(meta){
  // Coverage 真实绑定：有值才显示；无则显示"Coverage 暂不可用"
  if (!meta) return '';
  if (meta.coverage_days == null || meta.expected_days == null)
    return `<span class="badge gray">Coverage 暂不可用</span>`;
  const ok = !!meta.coverage_complete;
  const cls = ok ? 'green' : 'amber';
  const label = ok ? '覆盖完整' : '覆盖不完整';
  return `<span class="badge ${cls}">${label} ${meta.coverage_days}/${meta.expected_days}天</span>`;
}
const GAP_CN = {
  NO_DATA: '当前区间无数据',
  PARTIAL_DATA: '部分数据可用',
  WHITELIST_GAP: '数据库能力已存在，正式接口待开放',
  WRAPPER_GAP: '正式数据库能力已存在，工作台接口待接入',
  DATA_ONBOARDING_GAP: '已有原始数据，尚未进入正式经营数据层',
  UNSUPPORTED_METRIC: '当前数据粒度不支持该指标',
  SOURCE_NOT_AVAILABLE: '当前没有对应源数据',
  REFRESH_STALE: '最新经营数据已更新，智能分析尚未刷新',
};
function StateNotice(state, text){
  const cn = GAP_CN[state] || '能力未就绪';
  if (state === 'NO_DATA') return `<div class="empty">${esc(text)}（当前区间无数据）</div>`;
  if (state === 'SOURCE_NOT_AVAILABLE' || state === 'UNSUPPORTED_METRIC' || state === 'WHITELIST_GAP' || state === 'WRAPPER_GAP' || state === 'DATA_ONBOARDING_GAP' || state === 'REFRESH_STALE' || state === 'PARTIAL_DATA')
    return `<div class="notice amber"><b>${state}</b> ｜ ${cn}${text ? '：' + esc(text) : ''}</div>`;
  return `<div class="err">${esc(text)}</div>`;
}
// 统一错误渲染：NO_DATA（接口存在、查询合法、区间无数据）→ 空态；其余 → 错误
function errBlock(e, emptyText, colspan){
  if (e.code === 'NO_DATA') return `<tr><td colspan="${colspan||4}" class="empty">${emptyText||'当前区间无数据'}</td></tr>`;
  return `<div class="err">${esc(e.message)}</div>`;
}
function TrendSvg(points, field, w, h){
  w = w || 560; h = h || 130;
  const vals = (points||[]).map(p => p[field]).filter(v => v != null);
  if (!vals.length) return `<div class="empty">当前区间无${field}数据</div>`;
  const mx = Math.max(...vals), mn = Math.min(...vals);
  const px = i => i/(vals.length-1||1)*(w-20)+10, py = v => h-20-(v-mn)/(mx-mn||1)*(h-40);
  const poly = points.filter(p=>p[field]!=null).map((p,i)=>px(i)+','+py(Number(p[field]))).join(' ');
  const dots = points.filter(p=>p[field]!=null).map((p,i)=>`<circle cx="${px(i)}" cy="${py(Number(p[field]))}" r="2.5" fill="#2563eb"><title>${p.date}：${fmt(p[field])}</title></circle>`).join('');
  return `<svg viewBox="0 0 ${w} ${h}" style="width:100%;max-height:170px"><polyline points="${poly}" fill="none" stroke="#2563eb" stroke-width="2"/><line x1="10" y1="${h-20}" x2="${w-10}" y2="${h-20}" stroke="#e5e7eb"/>${dots}</svg>
    <div class="trend-note">数据粒度：日 ｜ 来源：经营数据库（mart 白名单）｜ 悬停数据点查看当日数值</div>`;
}

// ============================================================================
// 页面渲染（18 个业务路由各自独立：独立 API、独立业务参数、独立空态）
// ============================================================================
const PAGES = {

  // ---- /today 经营驾驶舱：唯一允许"今日经营"标题的页面（标题随查询区间变化）----
  '/today': async (f)=>{
    const q = {start_date:f.sd, end_date:f.ed, scope_key:f.scope};
    if (f.shop) q.shop_code = f.shop;
    // 标题语义：单日=今日经营/单日经营；多日=经营概览
    const isOneDay = f.sd === f.ed;
    const title = isOneDay ? (f.sd === MX ? '今日经营' : '单日经营') : '经营概览';
    const subDate = isOneDay ? f.sd : `${f.sd} ～ ${f.ed}`;
    let html = `<h1>${title}</h1><div class="sub">${f.shop_name||'抖音整体'} ｜ ${subDate} ｜ ${f.scope}</div>`;
    try {
      const cur = await api('/business/summary', q);
      const c = cur.data;
      let pv = {}, pvr = null;
      try { pv = (await api('/business/compare', {...q, metric_key:'user_pay_amount'})).data; } catch(e){}
      let pvr_pp = null; try { pvr_pp = (await api('/business/compare', {...q, metric_key:'refund_rate_pay_time'})).data.percentage_point_change; } catch(e){}
      html += `<div class="kpis">` +
        MetricCard('成交金额', c.transaction_amount) +
        MetricCard('用户支付金额', c.user_pay_amount, {chg: pv.absolute_change}) +
        MetricCard('退款金额(支付时间)', c.refund_amount_pay_time) +
        MetricCard('结算金额', c.settlement_amount) +
        MetricCard('退款率', c.refund_rate, {isRate:true, goodWhen:'low', chg: pvr_pp}) +
        MetricCard('投放消耗', c.ad_spend_shop_bound) +
        MetricCard('投放费比', c.ad_spend_rate_net_refund_shop_bound, {isRate:true, goodWhen:'low'}) +
        `</div>`;
      html += `<div class="card"><h3>成交金额趋势 ${covBadge(cur.meta)}</h3>`;
      try {
        const trend = await api('/business/trend', {...q, metric_key:'transaction_amount'});
        html += TrendSvg(trend.data, 'metric_value');
      } catch(e){ html += `<div class="err">趋势加载失败：${esc(e.message)}</div>`; }
      html += `</div>`;
    } catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
    // 风险/机会 TOP5 + 店铺贡献（首页摘要，完整列表在各独立页面）
    html += `<div class="grid2">`;
    try {
      const r = await api('/priorities/risks', {start_date:f.sd, end_date:f.ed, limit:5});
      html += `<div class="card"><h3>风险 TOP5 <span class="badge red">V1.1</span></h3><table><tr><th>对象</th><th>级别</th><th>得分</th><th>影响</th></tr>` +
        (r.data.length ? r.data.map(x=>`<tr><td><a href="#/risks">${esc(x.entity_name)}</a></td><td><span class="badge red">${esc(x.risk_level)}</span></td><td class="num">${fmt(x.risk_priority_score)}</td><td class="num">${yuan(x.business_impact)}</td></tr>`).join('') : `<tr><td colspan="4" class="empty">当前区间无风险</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card"><h3>风险 TOP5</h3>${errBlock(e, '当前区间无风险（V1.1 检测未覆盖新月份数据）', 4)}</div>`; }
    try {
      const o = await api('/priorities/opportunities', {start_date:f.sd, end_date:f.ed, limit:5});
      html += `<div class="card"><h3>机会 TOP5 <span class="badge green">V1.1</span></h3><table><tr><th>对象</th><th>级别</th><th>得分</th><th>机会分</th></tr>` +
        (o.data.length ? o.data.map(x=>`<tr><td><a href="#/opportunities">${esc(x.entity_name)}</a></td><td><span class="badge green">${esc(x.opportunity_level)}</span></td><td class="num">${fmt(x.opportunity_priority_score)}</td><td class="num">${fmt(x.opportunity_score)}</td></tr>`).join('') : `<tr><td colspan="4" class="empty">当前区间无机会</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card"><h3>机会 TOP5</h3>${errBlock(e, '当前区间无机会（V1.1 检测未覆盖新月份数据）', 4)}</div>`; }
    html += `</div>`;
    try {
      const sc = await api('/business/shop-contribution', {start_date:f.sd, end_date:f.ed, scope_key:f.scope});
      html += `<div class="card"><h3>店铺贡献（抖音整体）</h3><table><tr><th>店铺</th><th>当前值</th><th>贡献率</th><th>上期</th><th>贡献环比</th></tr>` +
        sc.data.shops.map(x=>`<tr><td>${esc(x.shop_name)}</td><td class="num">${yuan(x.current_value)}</td><td class="num">${pct(x.contribution)}</td><td class="num">${yuan(x.previous_value)}</td><td class="num">${x.contribution_change==null?'—':((x.contribution_change>=0?'+':'')+(x.contribution_change*100).toFixed(2)+' pp')}</td></tr>`).join('') + `</table></div>`;
    } catch(e){}
    return html;
  },

  // ---- /store 店铺经营：对比表 + 贡献 + 环比（前端不 SUM，全部来自正式接口）----
  '/store': async (f)=>{
    let html = `<h1>店铺经营</h1><div class="sub">${f.sd} ～ ${f.ed} ｜ ${f.scope} ｜ 平台整体 + 两店拆解（正式跨店聚合）</div>`;
    const shops = [['','抖音整体'],['DY_DANDONG_OFFICIAL','弹动官方旗舰店'],['DY_GERENHULI_OFFICIAL','弹动个人护理旗舰店']];
    const rows = [];
    try {
      for (const [code, name] of shops){
        const params = {start_date:f.sd, end_date:f.ed, scope_key:f.scope};
        if (code) params.shop_code = code;
        const r = await api('/business/summary', params);
        rows.push({name, ...r.data});
      }
      html += `<div class="card"><table><tr><th>店铺</th><th>成交金额</th><th>结算金额</th><th>退款率</th><th>投放消耗</th><th>投放费比</th></tr>` +
        rows.map(x=>`<tr><td><b>${esc(x.name)}</b></td><td class="num">${yuan(x.transaction_amount)}</td><td class="num">${yuan(x.settlement_amount)}</td><td class="num">${pct(x.refund_rate)}</td><td class="num">${yuan(x.ad_spend_shop_bound)}</td><td class="num">${pct(x.ad_spend_rate_net_refund_shop_bound)}</td></tr>`).join('') + `</table></div>`;
      const sc = await api('/business/shop-contribution', {start_date:f.sd, end_date:f.ed, scope_key:f.scope});
      html += `<div class="card"><h3>店铺贡献与环比</h3><table><tr><th>店铺</th><th>当前值</th><th>上期</th><th>贡献率</th><th>贡献环比</th></tr>` +
        sc.data.shops.map(x=>`<tr><td>${esc(x.shop_name)}</td><td class="num">${yuan(x.current_value)}</td><td class="num">${yuan(x.previous_value)}</td><td class="num">${pct(x.contribution)}</td><td class="num">${x.contribution_change==null?'—':((x.contribution_change>=0?'+':'')+(x.contribution_change*100).toFixed(2)+' pp')}</td></tr>`).join('') + `</table></div>`;
    } catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
    return html;
  },

  // ---- /priorities 经营优先级：主体是 Priority/Action，非通用 KPI ----
  '/priorities': async (f)=>{
    let html = `<h1>经营优先级</h1><div class="sub">${f.sd} ～ ${f.ed} ｜ 今天最应该做什么（V1.1 Priority，前端不重排）</div><div class="grid2">`;
    try {
      const r = await api('/priorities/risks', {start_date:f.sd, end_date:f.ed, limit:10});
      html += `<div class="card"><h3>风险优先级 <span class="badge red">V1.1</span></h3><table><tr><th>对象</th><th>级别</th><th>得分</th><th>影响金额</th></tr>` +
        (r.data.length ? r.data.map(x=>`<tr><td><a href="#/risks">${esc(x.entity_name)}</a></td><td><span class="badge red">${esc(x.risk_level)}</span></td><td class="num">${fmt(x.risk_priority_score)}</td><td class="num">${yuan(x.business_impact)}</td></tr>`).join('') : `<tr><td colspan="4" class="empty">当前区间无风险优先级</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card"><h3>风险优先级</h3>${errBlock(e, '当前区间无风险优先级（V1.1 检测未覆盖新月份）', 4)}</div>`; }
    try {
      const o = await api('/priorities/opportunities', {start_date:f.sd, end_date:f.ed, limit:10});
      html += `<div class="card"><h3>机会优先级 <span class="badge green">V1.1</span></h3><table><tr><th>对象</th><th>级别</th><th>得分</th><th>机会分</th></tr>` +
        (o.data.length ? o.data.map(x=>`<tr><td><a href="#/opportunities">${esc(x.entity_name)}</a></td><td><span class="badge green">${esc(x.opportunity_level)}</span></td><td class="num">${fmt(x.opportunity_priority_score)}</td><td class="num">${fmt(x.opportunity_score)}</td></tr>`).join('') : `<tr><td colspan="4" class="empty">当前区间无机会优先级</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card"><h3>机会优先级</h3>${errBlock(e, '当前区间无机会优先级（V1.1 检测未覆盖新月份）', 4)}</div>`; }
    html += `</div>`;
    try {
      const w = await api('/priorities/watchlist', {start_date:f.sd, end_date:f.ed, limit:10});
      html += `<div class="card"><h3>今日行动 / Watchlist</h3><table><tr><th>对象</th><th>类型</th><th>状态</th></tr>` +
        (w.data.length ? w.data.map(x=>`<tr><td>${esc(x.entity_name)}</td><td>${esc(x.item_type||'')}</td><td><span class="badge amber">WATCH</span></td></tr>`).join('') : `<tr><td colspan="3" class="empty">当前区间无观察项</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card"><h3>今日行动</h3>${errBlock(e, '当前区间无观察项（V1.1 检测未覆盖新月份）', 3)}</div>`; }
    return html;
  },

  // ---- /product-lines 品线：结构 + 成员 + 经营汇总（F1.0.2 接入正式白名单函数）----
  '/product-lines': async (f)=>{
    try {
      const pl = await api('/master-data/product-lines');
      let html = `<h1>品线分析</h1><div class="sub">Product Line → Master Product → 店铺商品（正式跨店聚合，仅 CONFIRMED）｜ ${f.sd} ～ ${f.ed}</div>`;
      for (const line of pl.data){
        const members = await api('/master-data/product-line-members', {product_line_code: line.product_line_code});
        let s = '';
        try {
          const sum = await api('/product-lines/summary', {product_line_name: line.product_line_name, start_date:f.sd, end_date:f.ed});
          s = `<div class="kpis" style="margin:6px 0">` +
            MetricCard('用户支付金额', sum.data.user_pay_amount) +
            MetricCard('退款金额(支付时间)', sum.data.refund_amount_pay_time) +
            MetricCard('映射 Master Product', sum.data.mapped_member_count) +
            MetricCard('覆盖店铺', sum.data.covered_shop_count) + `</div>` +
            `<div class="trend-note">映射完整性：${sum.data.mapping_complete?'完整':'不完整'}（${sum.data.mapped_member_count}/${sum.data.expected_member_count}）｜ 数据覆盖：${sum.data.data_coverage_complete?'完整':'不完整'}｜ 结算/投放/成交为品线粒度未支持指标</div>`;
        } catch(e){ s = `<div class="notice">${esc(e.message)}</div>`; }
        html += `<div class="card"><h3>${esc(line.product_line_name)} <span class="badge blue">${esc(line.product_line_code)}</span> <span class="badge gray">${members.data.length} 个 Master Product</span></h3>${s}` +
          `<table><tr><th>Master Product</th><th>编码</th><th>状态</th></tr>` +
          (members.data.length ? members.data.map(m=>`<tr><td><a href="#/master-products">${esc(m.master_product_name)}</a></td><td>${esc(m.master_product_code)}</td><td><span class="badge ${m.enabled?'green':'gray'}">${m.enabled?'启用':'停用'}</span></td></tr>`).join('') : `<tr><td colspan="3" class="empty">暂无成员</td></tr>`) + `</table></div>`;
      }
      return html;
    } catch(e){ return `<h1>品线分析</h1><div class="err">${esc(e.message)}</div>`; }
  },

  // ---- /master-products Master Product：主档 + 排名 + 跨店拆解（F1.0.2 接入正式白名单函数）----
  '/master-products': async (f)=>{
    try {
      const r = await api('/master-data/products', {page_size:100});
      const list = r.data || [];
      let html = `<h1>Master Product</h1><div class="sub">公司商品主档（跨店统一主商品；CONFIRMED 映射进入正式跨店汇总）｜ ${f.sd} ～ ${f.ed}</div>`;
      try {
        const rank = await api('/master-products/rank', {start_date:f.sd, end_date:f.ed, metric_key:'user_pay_amount', limit:50});
        html += `<div class="card"><h3>Master Product 经营排名（用户支付金额）<span class="badge green">正式接口</span></h3><table><tr><th>#</th><th>Master Product</th><th>品线</th><th>用户支付金额</th><th>映射店</th><th>映射完整</th></tr>` +
          (rank.data.length ? rank.data.map((x,i)=>`<tr><td>${i+1}</td><td><a href="#/master-products">${esc(x.master_product_name)}</a></td><td>${esc(x.product_line_name||'—')}</td><td class="num">${yuan(x.current_value)}</td><td class="num">${x.mapped_shop_count}</td><td>${x.mapping_complete?'<span class="badge green">完整</span>':'<span class="badge amber">不完整</span>'}</td></tr>`).join('') : `<tr><td colspan="6" class="empty">当前区间无排名数据</td></tr>`) + `</table></div>`;
      } catch(e){ html += `<div class="card"><h3>经营排名</h3>${errBlock(e, '当前区间无排名数据', 6)}</div>`; }
      html += `<div class="card"><h3>主档结构</h3><table><tr><th>编码</th><th>名称</th><th>状态</th></tr>` +
        (list.length ? list.map(m=>`<tr><td>${esc(m.master_product_code||'—')}</td><td>${esc(m.master_product_name||'—')}</td><td><span class="badge ${m.enabled?'green':'gray'}">${m.enabled?'启用':'停用'}</span></td></tr>`).join('') : `<tr><td colspan="3" class="empty">暂无主档数据</td></tr>`) + `</table></div>`;
      return html;
    } catch(e){ return `<h1>Master Product</h1><div class="err">${esc(e.message)}</div>`; }
  },

  // ---- /products 商品：平台商品排名（正式 rank_products，店铺级能力）----
  '/products': async (f)=>{
    // P0-04 修复：整体模式不偷偷默认官方店 → 明确要求选择店铺
    if (!f.shop) return `<h1>商品分析</h1>` + StateNotice('NOT_READY', '商品排名为店铺级能力（正式接口无平台级商品排名）。请在上方选择店铺（弹动官方旗舰店 / 弹动个人护理旗舰店）后查看。');
    const shopName = f.shop_name;
    try {
      const r = await api('/business/products/top', {shop_code:f.shop, start_date:f.sd, end_date:f.ed, limit:50});
      let html = `<h1>商品分析</h1><div class="sub">${shopName} ｜ ${f.sd} ～ ${f.ed} ｜ 按用户支付金额排序（正式 mart 排名）</div>`;
      html += `<div class="notice">商品退款/结算/投放列为正式接口未覆盖指标 → 不补造。</div>`;
      html += `<div class="card"><table><tr><th>#</th><th>商品</th><th>用户支付金额</th></tr>` +
        (r.data.length ? r.data.map((x,i)=>`<tr><td>${i+1}</td><td>${esc(x.product_name||x.shop_product_name)}</td><td class="num">${yuan(x.current_value)}</td></tr>`).join('') : `<tr><td colspan="3" class="empty">当前区间无商品数据</td></tr>`) + `</table></div>`;
      return html;
    } catch(e){ return `<h1>商品分析</h1><div class="err">${esc(e.message)}</div>`; }
  },

  // ---- /product-card 商品卡：scope=商品卡 正式口径（非全店经营）----
  '/product-card': async (f)=>{
    const params = {start_date:f.sd, end_date:f.ed, scope_key:'商品卡'};
    if (f.shop) params.shop_code = f.shop;
    let html = `<h1>商品卡经营</h1><div class="sub">${f.shop_name||'抖音整体'} ｜ ${f.sd} ～ ${f.ed} ｜ 口径：商品卡（正式 Scope，非全店）</div>`;
    try {
      const s = await api('/business/summary', params);
      html += `<div class="kpis">` +
        MetricCard('成交金额', s.data.transaction_amount) +
        MetricCard('用户支付金额', s.data.user_pay_amount) +
        MetricCard('退款率', s.data.refund_rate, {isRate:true, goodWhen:'low'}) +
        MetricCard('结算金额', s.data.settlement_amount) +
        MetricCard('投放消耗', s.data.ad_spend_shop_bound) + `</div>`;
      html += `<div class="card"><h3>商品卡成交金额趋势 ${covBadge(s.meta)}</h3>`;
      try { const t = await api('/business/trend', {...params, metric_key:'transaction_amount'}); html += TrendSvg(t.data, 'metric_value'); }
      catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
      html += `</div>`;
      // F1.0.3：商品卡快照（PERIOD_SNAPSHOT，周期×商品；禁日趋势）
      html += `<div class="card"><h3>商品卡快照（统计周期 ${f.sd} ～ ${f.ed}）<span class="badge green">PERIOD_SNAPSHOT</span></h3>`;
      try {
        const snap = await api('/product-card/snapshot-summary', {shop_code:f.shop||'DY_DANDONG_OFFICIAL', start_date:f.sd, end_date:f.ed});
        html += `<div class="kpis">` +
          MetricCard('覆盖商品', snap.data.product_count) +
          MetricCard('曝光人数', snap.data.exposure_users) +
          MetricCard('点击人数', snap.data.click_users) +
          MetricCard('快照用户支付金额', snap.data.user_pay_amount) +
          MetricCard('成交人数', snap.data.transaction_users) +
          MetricCard('成交订单', snap.data.transaction_orders) + `</div>`;
        const rank = await api('/product-card/snapshot-rank', {shop_code:f.shop||'DY_DANDONG_OFFICIAL', start_date:f.sd, end_date:f.ed, metric_key:'user_pay_amount', limit:20});
        html += `<table><tr><th>#</th><th>商品</th><th>用户支付金额</th></tr>` +
          (rank.data.length ? rank.data.map((x,i)=>`<tr><td>${i+1}</td><td>${esc(x.product_title||x.product_id)}</td><td class="num">${yuan(x.current_value)}</td></tr>`).join('') : `<tr><td colspan="3" class="empty">当前周期无商品卡快照数据</td></tr>`) + `</table>`;
      } catch(e){ html += `<div class="notice">快照暂不可用：${esc(e.message)}（商品卡快照为源文件导出周期，非日粒度）</div>`; }
      html += `<div class="trend-note">商品卡快照为统计周期导出（PERIOD_SNAPSHOT），不提供日趋势；仅展示周期内商品排名与汇总。</div></div>`;
    } catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
    return html;
  },

  // ---- /advertising 投放：正式广告口径（店铺级能力，费比直接消费 mart 结果）----
  '/advertising': async (f)=>{
    // P0-05 修复：整体模式不偷偷默认官方店 → 明确要求选择店铺
    if (!f.shop) return `<h1>投放经营</h1>` + StateNotice('NOT_READY', '投放接口为店铺级能力（get_advertising_period_summary 需指定店铺）。请在上方选择店铺后查看。');
    const shopName = f.shop_name;
    const params = {shop_code:f.shop, start_date:f.sd, end_date:f.ed, scope_key:f.scope};
    let html = `<h1>投放经营</h1><div class="sub">${shopName} ｜ ${f.sd} ～ ${f.ed} ｜ ${f.scope} ｜ 费比/效率全部来自正式 mart 口径</div>`;
    try {
      const s = await api('/advertising/summary', params);
      const m = s.data || {};
      html += `<div class="kpis">` +
        MetricCard('投放消耗(店铺被投)', m.ad_spend_shop_promoted) +
        MetricCard('投放消耗(店铺绑定)', m.ad_spend_shop_bound) +
        MetricCard('投放贡献成交', m.ad_attributed_transaction_amount) +
        MetricCard('投放贡献占比', m.ad_attributed_transaction_share, {isRate:true}) +
        MetricCard('投放费比', m.ad_spend_rate_net_refund_shop_bound, {isRate:true, goodWhen:'low'}) +
        MetricCard('综合费比', m.total_expense_rate_net_refund_shop_bound, {isRate:true, goodWhen:'low'}) +
        MetricCard('投放效率', m.ad_efficiency_shop_bound) +
        MetricCard('全店效率', m.store_efficiency_shop_bound) + `</div>`;
      html += `<div class="card"><h3>投放消耗趋势</h3>`;
      try { const t = await api('/business/trend', params); html += TrendSvg(t.data, 'metric_value'); }
      catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
      html += `</div>`;
      html += `<div class="notice">计划/单元/预算级投放明细未接入 → <b>KNOWN LIMITATION</b>（不补造）。</div>`;
    } catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
    return html;
  },

  // ---- /refund 退款：退款聚焦（金额/率/趋势/两店对比），原因分析 NOT_READY ----
  '/refund': async (f)=>{
    const q = {start_date:f.sd, end_date:f.ed, scope_key:f.scope};
    if (f.shop) q.shop_code = f.shop;
    let html = `<h1>退款分析</h1><div class="sub">${f.shop_name||'抖音整体'} ｜ ${f.sd} ～ ${f.ed} ｜ ${f.scope}</div>`;
    try {
      const s = await api('/business/summary', q);
      html += `<div class="kpis">` +
        MetricCard('退款金额(支付时间)', s.data.refund_amount_pay_time) +
        MetricCard('退款率', s.data.refund_rate, {isRate:true, goodWhen:'low'}) +
        MetricCard('成交金额', s.data.transaction_amount) +
        MetricCard('用户支付金额', s.data.user_pay_amount) + `</div>`;
      html += `<div class="card"><h3>退款率趋势（低优指标，上涨为风险）</h3>`;
      try { const t = await api('/business/trend', q); html += TrendSvg(t.data, 'metric_value'); }
      catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
      html += `</div>`;
      // 两店退款对比（正式接口）
      html += `<div class="card"><h3>两店退款对比</h3><table><tr><th>店铺</th><th>退款金额</th><th>退款率</th><th>用户支付金额</th></tr>`;
      for (const [code,name] of [['DY_DANDONG_OFFICIAL','弹动官方旗舰店'],['DY_GERENHULI_OFFICIAL','弹动个人护理旗舰店']]){
        try {
          const r = await api('/business/summary', {shop_code:code, start_date:f.sd, end_date:f.ed, scope_key:f.scope});
          html += `<tr><td>${name}</td><td class="num">${yuan(r.data.refund_amount_pay_time)}</td><td class="num">${pct(r.data.refund_rate)}</td><td class="num">${yuan(r.data.user_pay_amount)}</td></tr>`;
        } catch(e){ html += `<tr><td>${name}</td><td colspan="3" class="empty">无数据</td></tr>`; }
      }
      html += `</table></div>`;
      html += `<div class="notice">退款原因/售后原因数据源尚未接入 → <b>NOT_READY</b>（不制造"退款原因分析"假页面）。</div>`;
    } catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
    return html;
  },

  // ---- /accounts 达人/账号（P1-06：白名单正式函数；按自营/合作两区展示，'全部'无聚合行）----
  '/accounts': async (f)=>{
    if (!f.shop) return `<h1>达人 / 账号</h1>` + StateNotice('NOT_READY', '账号分析为店铺级能力（正式函数需指定店铺）。请在上方选择店铺后查看。');
    let html = `<h1>达人 / 账号</h1><div class="sub">${f.shop_name} ｜ ${f.sd} ～ ${f.ed} ｜ 正式 mart 账号层（自营 / 合作）</div>`;
    for (const sc of ['自营','合作']){
      try {
        const s = await api('/accounts/summary', {shop_code:f.shop, start_date:f.sd, end_date:f.ed, sale_scope:sc});
        const a = (s.data && s.data[0]) || {};
        html += `<div class="kpis">` +
          MetricCard(sc+' 账号成交金额', a.transaction_amount) +
          MetricCard(sc+' 用户支付', a.user_pay_amount) +
          MetricCard(sc+' 退款率', a.refund_rate_pay_time, {isRate:true, goodWhen:'low'}) +
          MetricCard(sc+' 投放消耗', a.ad_spend_shop_bound) + `</div>`;
        const t = await api('/accounts/top', {shop_code:f.shop, start_date:f.sd, end_date:f.ed, sale_scope:sc, limit:25});
        html += `<div class="card"><h3>${sc}账号 TOP25（用户支付金额）</h3><table><tr><th>#</th><th>账号</th><th>类型</th><th>金额</th><th>退款率</th></tr>` +
          (t.data && t.data.length ? t.data.map((x,i)=>`<tr><td>${i+1}</td><td>${esc(x.account_name||'—')}</td><td>${esc(x.account_type||'—')}</td><td class="num">${yuan(x.current_value)}</td><td class="num">${x.refund_rate_pay_time!=null?pct(x.refund_rate_pay_time):'—'}</td></tr>`).join('') : `<tr><td colspan="5" class="empty">当前区间无${sc}账号数据</td></tr>`) + `</table></div>`;
      } catch(e){ html += `<div class="card"><h3>${sc}账号</h3><div class="err">${esc(e.message)}</div></div>`; }
    }
    return html;
  },

  // ---- /live 直播：scope=直播 正式摘要 + 明细 NOT_READY ----
  '/live': async (f)=>{
    const params = {start_date:f.sd, end_date:f.ed, scope_key:'直播'};
    if (f.shop) params.shop_code = f.shop;
    let html = `<h1>直播经营</h1><div class="sub">${f.shop_name||'抖音整体'} ｜ ${f.sd} ～ ${f.ed} ｜ 口径：直播（正式 Scope）+ 场次/日数据快照</div>`;
    try {
      const s = await api('/business/summary', params);
      html += `<div class="kpis">` +
        MetricCard('成交金额', s.data.transaction_amount) +
        MetricCard('用户支付金额', s.data.user_pay_amount) +
        MetricCard('退款率', s.data.refund_rate, {isRate:true, goodWhen:'low'}) +
        MetricCard('投放消耗', s.data.ad_spend_shop_bound) + `</div>`;
      html += `<div class="card"><h3>直播成交金额趋势</h3>`;
      try { const t = await api('/business/trend', {...params, metric_key:'transaction_amount'}); html += TrendSvg(t.data, 'metric_value'); }
      catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
      html += `</div>`;
      // F1.0.3：直播场次（SESSION_FACT）
      if (f.shop){
        try {
          const sess = await api('/live/sessions', {shop_code:f.shop, limit:200});
          if (sess.data.length){
            const pk = sess.data[0].period_key;
            html += `<div class="card"><h3>直播场次（${pk}，SESSION_FACT）<span class="badge green">真实场次</span></h3><table><tr><th>直播间</th><th>开始</th><th>结束</th><th>时长(分)</th><th>账号类型</th><th>达人</th></tr>` +
              sess.data.slice(0,30).map(x=>`<tr><td>${esc(x.live_room_name||x.live_room_id)}</td><td>${esc(x.start_time)}</td><td>${esc(x.end_time)}</td><td class="num">${x.duration_minutes!=null?fmt(x.duration_minutes):'—'}</td><td>${esc(x.account_type||'')}</td><td>${esc(x.creator_nickname||'')}</td></tr>`).join('') + `</table>` +
              (sess.data.length>30?`<div class="trend-note">共 ${sess.data.length} 场（前 30 场展示）</div>`:'') + `</div>`;
          } else html += `<div class="notice">当前区间无直播场次数据（场次为源文件导出周期）</div>`;
        } catch(e){ html += `<div class="notice">场次数据暂不可用：${esc(e.message)}</div>`; }
      }
      // F1.0.3：直播日数据（DAILY_FACT）
      if (f.shop){
        try {
          const daily = await api('/live/daily', {shop_code:f.shop});
          if (daily.data.length){
            html += `<div class="card"><h3>直播日数据（DAILY_FACT）</h3><table><tr><th>日期</th><th>成交金额</th><th>消耗</th><th>净成交ROI</th><th>GPM</th></tr>` +
              daily.data.map(x=>`<tr><td>${esc(x.biz_date||'周期汇总')}</td><td class="num">${yuan(x.transaction_amount)}</td><td class="num">${yuan(x.ad_spend)}</td><td class="num">${x.net_roi!=null?fmt(x.net_roi):'—'}</td><td class="num">${x.gpm!=null?fmt(x.gpm):'—'}</td></tr>`).join('') + `</table></div>`;
          }
        } catch(e){}
      }
      html += `<div class="notice">分钟级/时段级/直播商品级：当前源数据不支持 → <b>SOURCE_NOT_AVAILABLE</b>（不推算）。</div>`;
    } catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
    return html;
  },

  // ---- /video 短视频：scope=短视频 正式摘要 + 明细 NOT_READY ----
  '/video': async (f)=>{
    const params = {start_date:f.sd, end_date:f.ed, scope_key:'短视频'};
    if (f.shop) params.shop_code = f.shop;
    let html = `<h1>短视频经营</h1><div class="sub">${f.shop_name||'抖音整体'} ｜ ${f.sd} ～ ${f.ed} ｜ 口径：短视频（正式 Scope）</div>`;
    try {
      const s = await api('/business/summary', params);
      html += `<div class="kpis">` +
        MetricCard('成交金额', s.data.transaction_amount) +
        MetricCard('用户支付金额', s.data.user_pay_amount) +
        MetricCard('退款率', s.data.refund_rate, {isRate:true, goodWhen:'low'}) +
        MetricCard('投放消耗', s.data.ad_spend_shop_bound) + `</div>`;
      html += `<div class="card"><h3>短视频成交金额趋势</h3>`;
      try { const t = await api('/business/trend', {...params, metric_key:'transaction_amount'}); html += TrendSvg(t.data, 'metric_value'); }
      catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
      html += `</div>`;
      // F1.0.3：视频详情快照（PERIOD_SNAPSHOT）
      if (f.shop){
        try {
          const vs = await api('/video/snapshot-summary', {shop_code:f.shop, start_date:f.sd, end_date:f.ed});
          if (vs.data){
            html += `<div class="card"><h3>视频快照（周期 ${f.sd} ～ ${f.ed}）<span class="badge green">PERIOD_SNAPSHOT</span></h3>` +
              `<div class="kpis">` +
              MetricCard('覆盖视频', vs.data.video_count) +
              MetricCard('观看次数', vs.data.view_count) +
              MetricCard('视频用户支付金额', vs.data.user_pay_amount) +
              MetricCard('视频退款金额', vs.data.refund_amount) +
              MetricCard('成交订单', vs.data.transaction_orders) + `</div>`;
            const vr = await api('/video/snapshot-rank', {shop_code:f.shop, start_date:f.sd, end_date:f.ed, metric_key:'user_pay_amount', limit:20});
            html += `<table><tr><th>#</th><th>视频</th><th>类型</th><th>用户支付金额</th></tr>` +
              (vr.data.length ? vr.data.map((x,i)=>`<tr><td>${i+1}</td><td>${esc(x.video_title||x.video_id)}</td><td>${esc((x.selling_type||'')+(x.carrier_type||''))}</td><td class="num">${yuan(x.current_value)}</td></tr>`).join('') : `<tr><td colspan="4" class="empty">当前周期无视频快照</td></tr>`) + `</table>` +
              `<div class="trend-note">视频快照为统计周期导出（PERIOD_SNAPSHOT），不按发布时间做日趋势；视频按周期排名。</div></div>`;
          }
        } catch(e){ html += `<div class="notice">视频快照暂不可用：${esc(e.message)}</div>`; }
      }
      html += `<div class="notice">单视频日趋势/内容级拆解：源数据为区间快照 → <b>PERIOD_SNAPSHOT</b>（不伪装逐日内容趋势）。</div>`;
    } catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
    return html;
  },

  // ---- /search 搜索（无源）/ /materials 素材（F1.0.3 接入快照） ----
  '/search': async (f)=>{
    return `<h1>搜索</h1>` + StateNotice('SOURCE_NOT_AVAILABLE', '平台尚未导出搜索核心数据（无源文件、无正式表）');
  },
  '/materials': async (f)=>{
    let html = `<h1>素材</h1><div class="sub">素材分析快照（PERIOD_SNAPSHOT）｜ ${f.sd} ～ ${f.ed}</div>`;
    if (!f.shop){
      html += `<div class="notice">素材分析为店铺级数据，请选择店铺后查看。</div>`;
      return html;
    }
    try {
      const r = await api('/materials/snapshot-rank', {shop_code:f.shop, start_date:f.sd, end_date:f.ed, metric_key:'user_pay_amount', limit:50});
      html += `<div class="card"><h3>素材排名（用户实际支付金额）<span class="badge green">PERIOD_SNAPSHOT</span></h3><table><tr><th>#</th><th>素材</th><th>评估</th><th>用户实际支付金额</th></tr>` +
        (r.data.length ? r.data.map((x,i)=>`<tr><td>${i+1}</td><td>${esc(x.material_name||x.material_id)}</td><td>${esc(x.material_evaluation||'')}</td><td class="num">${yuan(x.current_value)}</td></tr>`).join('') : `<tr><td colspan="4" class="empty">当前周期无素材快照数据</td></tr>`) + `</table>` +
        `<div class="trend-note">素材为统计周期导出（PERIOD_SNAPSHOT），不做日趋势；ROI/效率仅用源值，不推算。</div></div>`;
    } catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
    return html;
  },

  // ---- /smart-operation 智能经营总入口：决策中心（风险/机会/Action 摘要 + AI 入口）----
  '/smart-operation': async (f)=>{
    let html = `<h1>智能经营</h1><div class="sub">${f.sd} ～ ${f.ed} ｜ 经营决策中心：智能层结果集中视图</div>`;
    html += `<div class="grid3">`;
    try {
      const r = await api('/priorities/risks', {start_date:f.sd, end_date:f.ed, limit:5});
      html += `<div class="card"><h3>当前风险摘要</h3><table><tr><th>对象</th><th>级别</th><th>得分</th></tr>` +
        (r.data.length ? r.data.map(x=>`<tr><td><a href="#/risks">${esc(x.entity_name)}</a></td><td><span class="badge red">${esc(x.risk_level)}</span></td><td class="num">${fmt(x.risk_priority_score)}</td></tr>`).join('') : `<tr><td colspan="3" class="empty">无</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card"><h3>当前风险摘要</h3>${errBlock(e, '无（V1.1 检测未覆盖新月份）', 3)}</div>`; }
    try {
      const o = await api('/priorities/opportunities', {start_date:f.sd, end_date:f.ed, limit:5});
      html += `<div class="card"><h3>当前机会摘要</h3><table><tr><th>对象</th><th>级别</th><th>得分</th></tr>` +
        (o.data.length ? o.data.map(x=>`<tr><td><a href="#/opportunities">${esc(x.entity_name)}</a></td><td><span class="badge green">${esc(x.opportunity_level)}</span></td><td class="num">${fmt(x.opportunity_priority_score)}</td></tr>`).join('') : `<tr><td colspan="3" class="empty">无</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card"><h3>当前机会摘要</h3>${errBlock(e, '无（V1.1 检测未覆盖新月份）', 3)}</div>`; }
    try {
      const w = await api('/priorities/watchlist', {start_date:f.sd, end_date:f.ed, limit:5});
      html += `<div class="card"><h3>今日 Action / Watchlist</h3><table><tr><th>对象</th><th>状态</th></tr>` +
        (w.data.length ? w.data.map(x=>`<tr><td>${esc(x.entity_name)}</td><td><span class="badge amber">WATCH</span></td></tr>`).join('') : `<tr><td colspan="2" class="empty">无</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card"><h3>今日 Action</h3>${errBlock(e, '无（V1.1 检测未覆盖新月份）', 2)}</div>`; }
    html += `</div>`;
    html += `<div class="card"><h3>AI 经营助手</h3><p style="font-size:13px">基于正式结果解释经营问题（不自行重算）：<a href="#/ai">进入 AI 助手 →</a></p></div>`;
    return html;
  },

  // ---- /risks 风险中心：完整列表（首页 TOP5 仅为摘要）----
  '/risks': async (f)=>{
    let html = `<h1>风险中心</h1><div class="sub">V1.1 异常检测正式结果 ｜ ${f.sd} ～ ${f.ed} ｜ 完整列表（支持按级别/域/店铺筛选见下方）</div>`;
    try {
      const r = await api('/risks/complete', {start_date:f.sd, end_date:f.ed, limit:200});
      html += `<div class="card"><table><tr><th>对象</th><th>域</th><th>级别</th><th>类型</th><th>当前值</th><th>变化</th><th>持续</th><th>覆盖率</th></tr>` +
        (r.data.length ? r.data.map(x=>`<tr><td><a href="#/diagnosis">${esc(x.entity_name)}</a></td><td>${esc(x.domain_key||'')}</td><td><span class="badge red">${esc(x.severity||'')}</span></td><td>${esc(x.anomaly_name_cn||x.anomaly_type||'')}</td><td class="num">${fmt(x.current_value)}</td><td class="num">${x.absolute_change!=null?((x.absolute_change>0?'+':'')+fmt(x.absolute_change)):'—'}</td><td class="num">${x.consecutive_day_count||''}天</td><td>${x.coverage_complete?'<span class="badge green">完整</span>':'<span class="badge amber">不完整</span>'}</td></tr>`).join('') : `<tr><td colspan="8" class="empty">当前区间无风险（Anomaly）</td></tr>`) + `</table></div>`;
      try {
        const s = await api('/risks/summary', {start_date:f.sd, end_date:f.ed});
        html += `<div class="card"><h3>异常摘要</h3><table><tr><th>域</th><th>类型</th><th>事件数</th><th>级别</th><th>影响金额</th></tr>` +
          (s.data.length ? s.data.map(x=>`<tr><td>${esc(x.domain_key)}</td><td>${esc(x.anomaly_name_cn||x.anomaly_type)}</td><td class="num">${x.event_count}</td><td><span class="badge red">${esc(x.severity)}</span></td><td class="num">${yuan(x.total_materiality)}</td></tr>`).join('') : `<tr><td colspan="5" class="empty">无</td></tr>`) + `</table></div>`;
      } catch(e){}
    } catch(e){ html += `<div class="card">${errBlock(e, '当前区间无风险（V1.1 检测未覆盖新月份数据）', 8)}</div>`; }
    return html;
  },

  // ---- /diagnosis 问题诊断：数据定位（非因果）----
  '/diagnosis': async (f)=>{
    let html = `<h1>问题诊断</h1><div class="sub">V1.1 诊断正式结果 ｜ ${f.sd} ～ ${f.ed} ｜ 数据定位，非因果结论 ｜ 平台级诊断（正式接口无店铺维度）</div>`;
    try {
      const r = await api('/diagnostics/results', {start_date:f.sd, end_date:f.ed, domain_key:'shop'});
      html += `<div class="card"><table><tr><th>诊断类型</th><th>Primary Stage</th><th>置信度</th><th>当前值</th><th>变化</th><th>证据</th></tr>` +
        (r.data.length ? r.data.map(x=>`<tr><td>${esc(x.diagnostic_code)}</td><td><span class="badge blue">${esc(x.primary_stage)}</span></td><td class="num">${pct(x.confidence_score)}</td><td class="num">${fmt(x.current_value)}</td><td class="num">${fmt(x.absolute_change)}</td><td style="font-size:11px;color:var(--muted)">${esc((x.evidence_json||'').slice(0,60))}</td></tr>`).join('') : `<tr><td colspan="6" class="empty">当前区间无诊断结果</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card">${errBlock(e, '当前区间无诊断结果（V1.1 检测未覆盖新月份数据）', 6)}</div>`; }
    try {
      const d = await api('/diagnostics/decomposition', {start_date:f.sd, end_date:f.ed});
      const x = d.data;
      html += `<div class="card"><h3>变化拆解（${f.sd} ~ ${f.ed} vs 上期）</h3><table><tr><th>净变化</th><th>负向贡献</th><th>正向抵消</th></tr>` +
        `<tr><td class="num" style="color:${x.net_change<0?'var(--red)':'var(--green)'}">${yuan(x.net_change)}</td><td class="num" style="color:var(--red)">${yuan(x.gross_negative)}</td><td class="num" style="color:var(--green)">${yuan(x.gross_positive)}</td></tr></table></div>`;
    } catch(e){}
    return html;
  },

  // ---- /opportunities 增长机会：完整机会中心（首页 TOP5 仅为摘要）----
  '/opportunities': async (f)=>{
    let html = `<h1>增长机会</h1><div class="sub">V1.1 机会正式结果 ｜ ${f.sd} ～ ${f.ed} ｜ Opportunity Score 是机会质量排序，不是未来成功概率</div>`;
    try {
      const o = await api('/opportunities/complete', {start_date:f.sd, end_date:f.ed, limit:200});
      html += `<div class="card"><table><tr><th>对象</th><th>域</th><th>机会分</th><th>级别</th><th>当前值</th><th>相对变化</th><th>Peer基准</th><th>可用权重</th></tr>` +
        (o.data.length ? o.data.map(x=>`<tr><td><a href="#/opportunities">${esc(x.entity_name)}</a></td><td>${esc(x.domain_key||'')}</td><td class="num">${fmt(x.opportunity_score)}</td><td><span class="badge green">${esc(x.opportunity_level)}</span></td><td class="num">${fmt(x.current_value)}</td><td class="num">${x.relative_change!=null?((x.relative_change>0?'+':'')+(x.relative_change*100).toFixed(1)+'%'):'—'}</td><td class="num">${x.benchmark_p50!=null?fmt(x.benchmark_p50):'—'}</td><td class="num">${x.available_weight!=null?fmt(x.available_weight)+' 分':'—'}</td></tr>`).join('') : `<tr><td colspan="8" class="empty">当前区间无机会</td></tr>`) + `</table></div>`;
      try {
        const s = await api('/opportunities/summary', {start_date:f.sd, end_date:f.ed});
        html += `<div class="card"><h3>机会摘要</h3><table><tr><th>域</th><th>类型</th><th>事件数</th><th>最高分</th><th>平均分</th></tr>` +
          (s.data.length ? s.data.map(x=>`<tr><td>${esc(x.domain_key)}</td><td>${esc(x.opportunity_name_cn||x.opportunity_code)}</td><td class="num">${x.event_count}</td><td class="num">${fmt(x.max_score)}</td><td class="num">${fmt(x.avg_score)}</td></tr>`).join('') : `<tr><td colspan="5" class="empty">无</td></tr>`) + `</table></div>`;
      } catch(e){}
    } catch(e){ html += `<div class="card">${errBlock(e, '当前区间无机会（V1.1 检测未覆盖新月份数据）', 8)}</div>`; }
    return html;
  },

  // ---- /ai AI 经营助手（上下文继承筛选；AI 只解释正式结果）----
  '/ai': async (f)=>{
    const ctx = `店铺：${f.shop_name||'抖音整体'} ｜ 日期：${f.sd}~${f.ed} ｜ Scope：${f.scope}`;
    return `<h1>AI 经营助手</h1><div class="sub">AI 只解释正式结果，不自行重算；上下文自动继承当前筛选</div>
      <div class="notice">当前上下文：${ctx}</div>
      <div class="card"><h3>快捷问题</h3><table><tr><th>问题</th><th>回答方式</th></tr>
      <tr><td>为什么下降？</td><td>引用变化拆解/诊断正式结果（当前数据表明…）</td></tr>
      <tr><td>最大风险是什么？</td><td>引用 get_daily_risk_priorities 正式结果（TOP1）</td></tr>
      <tr><td>最大机会是什么？</td><td>引用 get_daily_opportunity_priorities 正式结果（TOP1）</td></tr>
      <tr><td>哪个商品拖累最大？</td><td>引用 decompose 负向贡献/rank_products 正式结果</td></tr>
      <tr><td>最近 ${f.sd}~${f.ed} 发生了什么？</td><td>引用 business/summary + compare 正式结果</td></tr></table>
      <p style="margin-top:10px;font-size:12px;color:var(--muted)">AI 边界：不能修改 Priority/Opportunity Score；不能自算退款率；不能编造异常（V1.1 AI 铁律）。真实 LLM 接入见部署配置。</p></div>`;
  },

  // ---- 平台页（保留原实现）----
  '/data-center': async (f)=>{
    try {
      const r = await api('/data-status');
      return `<h1>数据中心</h1><div class="sub">为什么今天没数据？先看这里：源文件未导入 / 导入失败 / 数据不完整 / 业务为 0</div><div class="card"><table><tr><th>店铺</th><th>最早日期</th><th>最新日期</th><th>天数</th><th>行数</th><th>时间类型</th><th>状态</th></tr>` +
        r.data.map(x=>`<tr><td>${esc(x.shop_name)}</td><td>${x.min_date}</td><td>${x.max_date}</td><td class="num">${x.day_count}</td><td class="num">${x.row_count}</td><td>DAILY_FACT</td><td><span class="badge green">OK</span></td></tr>`).join('') + `</table></div>`;
    } catch(e){ return `<h1>数据中心</h1><div class="err">${esc(e.message)}</div>`; }
  },
  '/system-status': async (f)=>{
    try {
      const h = await api('/health'), r = await api('/ready');
      return `<h1>系统状态</h1><div class="card"><table><tr><td>Web</td><td><span class="badge green">正常</span></td></tr><tr><td>Backend</td><td><span class="badge green">${esc(h.data.service)}</span></td></tr><tr><td>Database</td><td><span class="badge green">正常（店铺 ${r.data.shop_count} 家）</span></td></tr><tr><td>关键 Function 样例</td><td>${r.data.sample_value!=null?'正常（'+yuan(r.data.sample_value)+'）':'—'}</td></tr></table></div>`;
    } catch(e){ return `<h1>系统状态</h1><div class="err">${esc(e.message)}</div>`; }
  },
  '/data-status': async (f)=>{
    try {
      const r = await api('/data-status');
      return `<h1>数据状态</h1><div class="card"><table><tr><th>店铺</th><th>最早</th><th>最新</th><th>天数</th><th>行数</th><th>时间类型</th><th>状态</th></tr>` +
        r.data.map(x=>`<tr><td>${esc(x.shop_name)}</td><td>${x.min_date}</td><td>${x.max_date}</td><td class="num">${x.day_count}</td><td class="num">${x.row_count}</td><td>DAILY_FACT</td><td><span class="badge green">OK</span></td></tr>`).join('') + `</table></div>`;
    } catch(e){ return `<h1>数据状态</h1><div class="err">${esc(e.message)}</div>`; }
  },
};
// 路由别名：/ 与 /diagnostics 兼容
PAGES['/'] = PAGES['/today'];
PAGES['/diagnostics'] = PAGES['/diagnosis'];
PAGES['/refunds'] = PAGES['/refund'];
PAGES['/videos'] = PAGES['/video'];
PAGES['/shop'] = PAGES['/store'];

// ============================================================================
// 渲染：Sidebar / Filters（按页面能力矩阵）/ StatusBar（查询区间与系统最新日期分离）/ Page
// ============================================================================
function renderSide(){
  const cur = G.page;
  $('#side').innerHTML = `<div class="logo">抖音智能<br>经营工作台</div>` + MENU.map(m =>
    (m[0] && m[0].startsWith('/'))
      ? `<a href="#${m[0]}" class="${cur===m[0]?'active':''}">${m[1]}</a>`
      : `<div class="grp">${m[1]}</div>`
  ).join('');
}
function renderFilters(){
  const meta = PAGE_META[G.page] || PAGE_META['/today'];
  G.shop_name = G.shop ? SHOP_NAMES[G.shop] : '抖音整体';
  G.preset = derivePreset(G.sd, G.ed);
  const sel = v => `value="${v}"`;
  $('#filters').innerHTML = `
    <div class="field"><label>平台</label><select disabled><option>douyin（固定）</option></select></div>
    ${meta.supports_shop ? `<div class="field"><label>店铺</label><select id="f_shop">
      <option ${sel('')}>抖音整体</option><option ${sel('DY_DANDONG_OFFICIAL')}>弹动官方旗舰店</option><option ${sel('DY_GERENHULI_OFFICIAL')}>弹动个人护理旗舰店</option></select></div>` : ''}
    <div class="field"><label>日期</label><select id="f_mode">${Object.keys(PRESET_CN).map(k=>`<option ${G.preset===k?'selected':''}>${PRESET_CN[k]}</option>`).join('')}</select></div>
    ${G.preset==='custom' ? `<div class="field"><label>开始</label><input type="date" id="f_sd" value="${G.sd}"></div><div class="field"><label>结束</label><input type="date" id="f_ed" value="${G.ed}"></div>` : `<div class="field"><label>区间</label><input type="date" value="${G.sd}" disabled style="background:#f9fafb"></div><div class="field"><label>～</label><input type="date" value="${G.ed}" disabled style="background:#f9fafb"></div>`}
    ${meta.supports_scope ? `<div class="field"><label>Scope</label><select id="f_scope">${SCOPES.map(s=>`<option ${s===G.scope?'selected':''}>${s}</option>`).join('')}</select></div>` : `<div class="field"><label>Scope</label><select disabled><option>${G.scope}（当前模块不适用）</option></select></div>`}`;
  if (meta.supports_shop){ $('#f_shop').value = G.shop; $('#f_shop').onchange = e=>{ G.shop = e.target.value; saveG(); renderFilters(); renderPage(); }; }
  if (meta.supports_scope){ $('#f_scope').value = G.scope; $('#f_scope').onchange = e=>{ G.scope = e.target.value; saveG(); renderFilters(); renderPage(); }; }
  $('#f_mode').onchange = e=>{
    const k = Object.keys(PRESET_CN).find(x=>PRESET_CN[x]===e.target.value);
    applyPreset(k); saveG(); renderFilters(); renderPage();
  };
  const fd = $('#f_sd'), fe = $('#f_ed');
  if (fd) fd.onchange = e=>{ G.sd = e.target.value; G.preset = 'custom'; saveG(); location.hash = G.page; };
  if (fe) fe.onchange = e=>{ G.ed = e.target.value; G.preset = 'custom'; saveG(); location.hash = G.page; };
  renderStatus();
}
function renderStatus(){
  // 查询区间 与 系统最新入库日期 是两个独立概念，分开展示
  $('#status').innerHTML = `<span>查询区间：<b>${G.sd||'—'} ～ ${G.ed||'—'}</b>（${PRESET_CN[G.preset]||''}）</span>
    <span>系统最新入库数据：<b>${MX||'—'}</b></span>
    <span>店铺：<b>${G.shop_name||'抖音整体'}</b></span>
    <span>Scope：<b>${G.scope}</b></span>`;
}
async function renderPage(){
  const fn = PAGES[G.page] || PAGES['/today'];
  $('#page').innerHTML = `<div class="loading">加载中…</div>`;
  try { $('#page').innerHTML = await fn(G); }
  catch(e){ $('#page').innerHTML = `<div class="err">加载失败：${esc(e.message)}</div>`; }
  // F1.0.2 九：智能经营/风险/机会/优先级页注入 intelligence_status（STALE 显示"智能分析尚未刷新"，禁止显示"无风险"）
  if (['/smart-operation','/risks','/opportunities','/priorities','/diagnosis'].includes(G.page)){
    try {
      const st = await api('/intelligence-status');
      const d = st.data;
      if (d.intelligence_status === 'STALE'){
        const bar = `<div class="notice amber" style="margin-bottom:12px"><b>REFRESH_STALE</b> ｜ 智能分析尚未刷新：最新经营数据 ${esc(d.latest_fact_date)} 晚于智能结果 ${esc(d.latest_anomaly_generated_date||'—')}。本页显示的是最近一次智能检测结果，不代表"当前无风险/无机会"。</div>`;
        $('#page h1').after(bar);
      }
    } catch(e){ /* 状态不可用时静默 */ }
  }
  // CSV 导出（数字直接来自当前 API 返回，前端不聚合）
  const t = $('#page table');
  if (t){
    const btn = document.createElement('button');
    btn.textContent = '导出 CSV';
    btn.style.cssText = 'margin:0 0 10px;padding:6px 14px;border:none;background:var(--accent);color:#fff;border-radius:8px;cursor:pointer;font-size:13px';
    btn.onclick = () => {
      const rows = [...t.rows].map(r => [...r.cells].map(c => c.innerText.replace(/\n/g,' ').trim()));
      const csv = rows.map(r => r.map(c => '"' + c.replace(/"/g,'""') + '"').join(',')).join('\r\n');
      const blob = new Blob(['\ufeff' + csv], {type:'text/csv;charset=utf-8'});
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = `export_${G.page.slice(1)||'today'}_${G.sd}_${G.ed}.csv`;
      a.click();
      URL.revokeObjectURL(a.href);
    };
    $('#page h1').after(btn);
  }
}

// ============================================================================
// 初始化：先取系统最新入库日期（MX），再推导日期状态，最后渲染
// ============================================================================
window.addEventListener('hashchange', ()=>{ G.page = location.hash.slice(1)||'/today'; renderSide(); renderFilters(); renderPage(); });
(async function init(){
  try {
    const r = await api('/data-status', {platform_code:'douyin'});
    const rows = r.data || [];
    rows.forEach(x=>{ if (x.max_date && (!MX || x.max_date > MX)) MX = x.max_date; });
  } catch(e) {}
  // 首次访问（无 localStorage）默认近 7 天；已有值则推导 preset
  if (!G.sd || !G.ed){ applyPreset('last7days'); }
  else { G.preset = derivePreset(G.sd, G.ed); }
  if (!G.sd) { G.sd = addDay(MX||'2026-08-07', -6); }
  renderSide(); renderFilters(); renderPage();
})();
