// Exercise the real SPX mapped-levels page's quote effects and row buttons.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const ts = require('typescript');
const pageFile = path.resolve(__dirname, '../src/app/spx-map-reports/[jobId]/mapped-levels/page.tsx');
const code = ts.transpileModule(fs.readFileSync(pageFile, 'utf8'), { compilerOptions: {
  module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX, target: ts.ScriptTarget.ES2020,
} }).outputText;
const states = [
  { primary_supports: [{ zone_low: 7700.3, zone_high: 7709.7, tradable_center: 7704.5 }], downside_support_path: [{ label: 'Next support', price: 7650 }] },
  { historical_closes: { SPX: 7700, SPY: 773.13, QQQ: 725.21, SPXL: 290.76, TQQQ: 72.61, ESMain: 7799.25, NQMain: 29997.5 },
    historical_close_dates: { SPX: '2026-10-21', ESMain: '2026-10-21' }, historical_close_date: '2026-10-21', calibration_eligible: false,
    report_as_of_et: '2026-10-21T21:20:00-04:00', effective_prices: { SPX: 7710, SPY: 774.13, ESMain: 7809.25, QQQ: 710.5, TQQQ: 65.25, SPXL: 283.2, NQMain: 30001.25 },
    effective_price_timestamp: '2026-10-21T21:00:00', effective_price_timestamps: { QQQ: '2026-10-21T21:00:00', TQQQ: '2026-10-21T21:00:00', SPXL: '2026-10-21T21:00:00', NQMain: '2026-10-21T21:00:00', ESMain: '2026-10-21T21:00:00' }, effective_price_source: 'ESMain completed 30M bar', effective_price_basis: 99.25 },
  {}, 'loading', 'loading', {}, false, '', false, null, {}, 'loading', null, null, {}, {},
];
let cursor = 0;
let effects = [];
const intervals = [];
const requests = [];
const manualRef = { current: new Map() };
let spyUnauthorized = false;
let reproQuotes = false;
let reproSpyPrice = 764.15;
let reproQqqPrice = 707.15;
let nvdaManualPrice = 195;
global.window = { setInterval: (fn, delay) => { intervals.push({ fn, delay }); return intervals.length; }, clearInterval: () => {},
  setTimeout: () => 1, clearTimeout: () => {} };
const element = (type, props) => ({ type, ...props });
const react = { use: () => ({ jobId: 'fixture' }), useEffect: f => effects.push(f), useMemo: f => f(), useRef: () => manualRef,
  useState: () => { const i = cursor++; return [states[i], (update) => { states[i] = typeof update === 'function' ? update(states[i]) : update; }]; } };
const authenticatedFetch = async (url) => {
  requests.push(String(url));
  const requested = new URL(String(url), 'http://localhost');
  const symbol = requested.searchParams.get('symbol');
  if (spyUnauthorized && symbol === 'SPY') return { ok: false, status: 401 };
  let payload;
  if (requested.pathname.endsWith('/spx-map-extra-prices')) payload = {
    historical_closes: { NVDA: 200, SQQQ: 30 }, historical_close_dates: { NVDA: '2026-10-21', SQQQ: '2026-10-20' },
    historical_close_source: '30m_regular_session',
  };
  else if (requested.pathname.endsWith('/spx-map-live-extra-prices')) {
    const value = { NVDA: nvdaManualPrice, SQQQ: 30.5 }[symbol];
    payload = { live_prices: value ? { [symbol]: value } : {}, status: value ? 'available' : 'unavailable' };
  } else if (requested.pathname.endsWith('/spx-map-live-futures')) {
    const prices = { ESMain: 7721, NQMain: 29480.25 };
    payload = { live_prices: symbol ? { [symbol]: prices[symbol] } : prices, status: 'available' };
  } else {
    const prices = { SPY: 765.49, QQQ: 714.06, SPXL: 281.91, TQQQ: 68.86 };
    payload = { live_prices: symbol ? { [symbol]: reproQuotes ? { SPY: reproSpyPrice, QQQ: reproQqqPrice }[symbol] : { ...prices, QQQ: 710, SPY: 766.8, SPXL: 275, TQQQ: 65 }[symbol] } : prices, status: 'available' };
  }
  return { ok: true, json: async () => payload };
};
const m = new Module(pageFile, module);
m.filename = pageFile;
m.paths = Module._nodeModulePaths(path.dirname(pageFile));
const originalRequire = m.require.bind(m);
m.require = id => {
  if (id === 'react') return react;
  if (id === 'react/jsx-runtime') return { jsx: element, jsxs: element, Fragment: 'fragment' };
  if (id === './calibration' || id === './esBasis') {
    const file = path.resolve(path.dirname(pageFile), `${id.slice(2)}.ts`);
    const child = new Module(file, m);
    child._compile(ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText, file);
    return child.exports;
  }
  if (id.endsWith('authenticatedFetch')) return { authenticatedFetch };
  if (id.startsWith('../../../')) return { __esModule: true, default: id, levelReportKey: () => '', parseHtmlLevelDetails: () => ({}) };
  return originalRequire(id);
};
m._compile(code, pageFile);
const { matchedEsBasis, spxEsLevel } = m.require('./esBasis');
assert.equal(matchedEsBasis({ historical_closes: { SPX: 7700, ESMain: 7687.5 }, historical_close_dates: { SPX: '2026-10-21', ESMain: '2026-10-21' } }), -12.5);
assert.equal(spxEsLevel(7700, -12.5), 'SPX 7,700.00 · ES 7,687.50 (ES−SPX -12.50)');
assert.equal(matchedEsBasis({ historical_closes: { SPX: 7700, ESMain: 7687.5 }, historical_close_dates: { SPX: '2026-10-21', ESMain: '2026-10-20' } }), null);
assert.equal(matchedEsBasis({ historical_closes: { SPX: 7700 }, historical_close_dates: { SPX: '2026-10-21' } }), null);
const render = () => { cursor = 0; effects = []; return m.exports.default({ params: Promise.resolve({ jobId: 'fixture' }) }); };
function collect(node, type, result = []) {
  if (Array.isArray(node)) { node.forEach(n => collect(n, type, result)); return result; }
  if (!node || typeof node !== 'object') return result;
  if (typeof node.type === 'function') return collect(node.type(node), type, result);
  if (node.type === type) result.push(node);
  collect(node.children, type, result);
  return result;
}
function rowFor(tree, label) {
  const row = collect(tree, 'tr').find(tr => collect(tr, 'td')[0]?.children === label);
  assert.ok(row, `${label} row not rendered`);
  return row;
}
function checkUnavailable(tree, label) {
  const row = rowFor(tree, label);
  const cells = collect(row, 'td');
  assert.equal(collect(cells[3], 'div').length, 0, `${label} must not show a fallback range`);
  assert.equal(collect(cells[6], 'a').length, 0, `${label} must not offer orders without a ratio`);
  assert.match(row.className, /amber|red/);
}
function mappedRangeAndOrders(tree, symbol) {
  const cells = collect(rowFor(tree, symbol), 'td');
  return {
    range: JSON.stringify(cells[3]),
    orders: collect(cells[6], 'a').map(link => link.href),
    source: JSON.stringify(cells[5]),
  };
}
function refreshButton(tree, symbol) {
  const row = rowFor(tree, symbol);
  const button = collect(collect(row, 'td')[2], 'button')[0];
  assert.equal(button['aria-label'], `Refresh ${symbol} live price`);
  return button;
}
const flush = () => new Promise(resolve => setImmediate(resolve));
(async () => {
  const data = states[0], mapping = states[1];
  states[0] = null; states[1] = null;
  assert.doesNotThrow(() => render(), 'first render must work before data arrives');
  states[0] = data; states[1] = mapping;
  let tree = render();
  assert.match(JSON.stringify(tree), /SPX 7,704\.50 · ES 7,803\.75 \(ES−SPX \+99\.25\)/, 'zone anchor includes matched ES and basis');
  assert.match(JSON.stringify(tree), /SPX 7,650\.00 · ES 7,749\.25/, 'downside path shows translated ES level');
  assert.match(JSON.stringify(tree), /SPX 7,700\.30 · ES 7,799\.55/, 'zone boundary includes translated ES');
  const effectivePricesForClassification = states[1].effective_prices;
  states[0].primary_resistances = [
    { rank: 1, zone_low: 7719, zone_high: 7728, tradable_center: 7723.82 },
    { rank: 3, zone_low: 7691, zone_high: 7700, tradable_center: 7695.82 },
  ];
  states[1].effective_prices = { ...effectivePricesForClassification, SPX: 7644.2 };
  const resistanceTree = JSON.stringify(render());
  assert.match(resistanceTree, /text-red-700/, 'levels above the effective SPX are classified as resistance');
  const nearestResistance = resistanceTree.indexOf('7,695.82');
  const fartherResistance = resistanceTree.indexOf('7,723.82');
  assert.ok(nearestResistance >= 0 && nearestResistance < fartherResistance, 'nearest resistance sorts before farther resistance');
  assert.match(resistanceTree.slice(nearestResistance - 500, nearestResistance), /Resistance.*#.*1/, 'nearest resistance is renumbered Resistance #1 regardless of report rank');
  states[1].effective_prices = effectivePricesForClassification;
  delete states[0].primary_resistances;
  states[1].historical_close_dates.ESMain = '2026-10-20';
  const effectivePrices = states[1].effective_prices;
  states[1].effective_prices = { SPX: null, SPY: null, ESMain: null };
  const stale = render();
  assert.match(JSON.stringify(stale), /SPX 7,704\.50 · ES n\/a/, 'stale ES close must not generate an ES level');
  assert.equal(mappedRangeAndOrders(stale, 'ESMain').range.includes('n/a'), true, 'stale ES close must not produce an ES mapped range');
  states[1].historical_close_dates.ESMain = '2026-10-21';
  states[1].effective_prices = effectivePrices;
  tree = render();
  assert.equal(collect(tree, 'details')[0].open, undefined, 'more stocks closed by default');
  assert.match(JSON.stringify(collect(rowFor(tree, 'SPXL'), 'td')[2]), /283\.20/, 'SPXL uses its report-time historical price');
  assert.match(JSON.stringify(collect(rowFor(tree, 'NQMain'), 'td')[2]), /30,001\.25/, 'NQMain uses its report-time historical price');
  assert.match(JSON.stringify(collect(rowFor(tree, 'SPY'), 'td')[2]), /774\.13/, 'SPY uses the report-time effective equivalent, not an IB tick');
  assert.match(JSON.stringify(collect(rowFor(tree, 'ESMain'), 'td')[2]), /7,809\.25/, 'ESMain uses the completed report-time bar');
  assert.match(JSON.stringify(tree), /Effective prices at the report as-of time/);
  assert.match(JSON.stringify(tree), /SPX equivalent: .*7,710\.00/);
  assert.match(JSON.stringify(tree), /QQQ: .*710\.50/);
  assert.match(JSON.stringify(tree), /TQQQ: .*65\.25/);
  assert.match(JSON.stringify(tree), /Completed QQQ bar: /);
  assert.ok(JSON.stringify(tree).includes('"2026-10-21T21:00:00"'), 'report-time QQQ/TQQQ bar timestamps are displayed');
  assert.match(JSON.stringify(tree), /SPXL: .*283\.20/);
  assert.match(JSON.stringify(tree), /NQMain: .*30,001\.25/);
  assert.match(JSON.stringify(tree), /Completed SPXL bar: /);
  assert.match(JSON.stringify(tree), /Completed NQMain bar: /);

  effects[1](); // initial stock batch
  effects[2](); // independent initial futures batch
  await flush();
  tree = render();
  assert.equal(requests.filter(url => url.endsWith('/spx-map-live-prices')).length, 1);
  assert.equal(requests.filter(url => url.endsWith('/spx-map-live-futures')).length, 1);
  assert.equal(intervals.length, 0, 'never poll IB automatically');
  assert.match(JSON.stringify(collect(rowFor(tree, 'QQQ'), 'td')[2]), /710\.50/, 'QQQ uses its report-time historical price');
  assert.match(JSON.stringify(collect(rowFor(tree, 'TQQQ'), 'td')[2]), /65\.25/, 'TQQQ uses its report-time historical price');
  assert.match(JSON.stringify(collect(rowFor(tree, 'QQQ'), 'td')[5]), /observed QQQ-SPY move spread/);
  assert.match(mappedRangeAndOrders(tree, 'SPXL').source, /SPY mapped % move × 3/);
  assert.match(mappedRangeAndOrders(tree, 'TQQQ').source, /QQQ mapped % move × 3/);
  const mappedLow = (symbol) => Number(String(collect(collect(rowFor(tree, symbol), 'td')[3], 'div')[0].children[0]).replaceAll(',', ''));
  const spyClose = states[1].historical_closes.SPY;
  const qqqClose = states[1].historical_closes.QQQ;
  assert.ok(Math.abs(mappedLow('SPXL') - states[1].historical_closes.SPXL * (1 + 3 * (mappedLow('SPY') / spyClose - 1))) < 0.04);
  assert.ok(Math.abs(mappedLow('TQQQ') - states[1].historical_closes.TQQQ * (1 + 3 * (mappedLow('QQQ') / qqqClose - 1))) < 0.04);
  assert.equal(requests.some(url => url.includes('live-extra-prices')), false);

  // Leveraged ranges depend on the mapped parent, not on their own IB ticks.
  const spxlBefore = mappedRangeAndOrders(tree, 'SPXL');
  const tqqqBeforeOwnQuote = mappedRangeAndOrders(tree, 'TQQQ');
  assert.throws(() => refreshButton(tree, 'SPXL'), /row not rendered|undefined/);
  assert.match(JSON.stringify(collect(rowFor(tree, 'SPXL'), 'td')[2]), /283\.20/);
  assert.deepEqual(mappedRangeAndOrders(tree, 'SPXL'), spxlBefore);
  assert.deepEqual(mappedRangeAndOrders(tree, 'TQQQ'), tqqqBeforeOwnQuote,
    'TQQQ range is derived from the report-time QQQ mapping, not a current TQQQ quote');
  assert.throws(() => refreshButton(tree, 'QQQ'), /row not rendered|undefined/);
  assert.throws(() => refreshButton(tree, 'TQQQ'), /row not rendered|undefined/);
  assert.match(JSON.stringify(collect(rowFor(tree, 'QQQ'), 'td')[2]), /710\.50/);
  assert.match(JSON.stringify(collect(rowFor(tree, 'TQQQ'), 'td')[2]), /65\.25/);

  // Report-time SPY and ESMain proxies are fixed to the selected report, not current IB ticks.
  assert.throws(() => refreshButton(tree, 'SPY'), /row not rendered|undefined/);
  assert.throws(() => refreshButton(tree, 'ESMain'), /row not rendered|undefined/);
  assert.throws(() => refreshButton(tree, 'NQMain'), /row not rendered|undefined/);
  assert.equal(requests.some(url => url.endsWith('/spx-map-live-futures?symbol=NQMain')), false, 'NQMain uses its report-time bar, not an IB refresh');

  const pane = collect(tree, 'details')[0];
  pane.onToggle({ currentTarget: { open: true } });
  tree = render();
  effects[3](); // fetch date-bound closes only
  await flush();
  tree = render();
  assert.ok(requests.some(url => url.includes('/spx-map-extra-prices?observation_date=2026-10-21')));
  assert.equal(requests.some(url => url.includes('live-extra-prices')), false, 'opening the pane must not subscribe to IB');
  assert.equal(intervals.length, 0);
  checkUnavailable(tree, 'NVDA');
  refreshButton(tree, 'NVDA').onClick();
  await flush();
  tree = render();
  assert.ok(requests.some(url => url.endsWith('/spx-map-live-extra-prices?symbol=NVDA')));
  const nvda = rowFor(tree, 'NVDA');
  const nvdaLinks = collect(collect(nvda, 'td')[6], 'a');
  assert.deepEqual(nvdaLinks.map(link => link.children), ['Buy range', 'Sell range', 'Sell put']);
  assert.match(nvdaLinks[2].href, /action=SELL/);
  const nvdaBefore = mappedRangeAndOrders(tree, 'NVDA');
  nvdaManualPrice = 193;
  refreshButton(tree, 'NVDA').onClick();
  await flush();
  tree = render();
  const nvdaAfter = mappedRangeAndOrders(tree, 'NVDA');
  assert.notEqual(nvdaAfter.range, nvdaBefore.range, 'extra-stock range must follow refreshed IB quote');
  assert.notDeepEqual(nvdaAfter.orders, nvdaBefore.orders, 'extra-stock order targets must follow new ratio');
  assert.match(nvdaAfter.source, /observed NVDA-SPY move spread/);
  checkUnavailable(tree, 'SQQQ'); // still unfetched despite NVDA success
  refreshButton(tree, 'SQQQ').onClick();
  await flush();
  tree = render();
  assert.match(JSON.stringify(collect(rowFor(tree, 'SQQQ'), 'td')[5]), /observed SQQQ-SPY move spread/);
  refreshButton(tree, 'SPCX').onClick(); // no IB tick: fail closed
  await flush();
  tree = render();
  checkUnavailable(tree, 'SPCX');
  assert.match(JSON.stringify(collect(rowFor(tree, 'SPCX'), 'td')[2]), /IB returned no SPCX price/);

  // Report-time SPY and ESMain proxies remain fixed while other quotes refresh.
  assert.match(JSON.stringify(collect(rowFor(tree, 'SPY'), 'td')[2]), /774\.13/);
  assert.match(JSON.stringify(collect(rowFor(tree, 'ESMain'), 'td')[2]), /7,809\.25/);
  assert.ok(requests.every(url => !url.includes("symbol=SPY") && !url.includes("symbol=ESMain")), 'proxy rows never request manual IB refreshes');
  const qqqRiskLinks = collect(collect(rowFor(tree, 'QQQ'), 'td')[6], 'a');
  assert.deepEqual(qqqRiskLinks.map(link => link.children), ['Buy range', 'Sell range', 'Sell put']);
  const extraRiskCells = collect(rowFor(tree, 'SQQQ'), 'td');
  assert.equal(collect(extraRiskCells[3], 'div').length, 2, 'extra stock can also display a high-risk range');
  assert.equal(collect(extraRiskCells[6], 'a').length, 3, 'extra-stock actions follow its displayed range');

  assert.equal(intervals.length, 0);
  console.log('Report-time SPX/SPY/ESMain proxy prices and relative zone classification; no proxy IB refreshes or extra-stock prefetch: OK');
})().catch(err => { console.error(err); process.exitCode = 1; });
