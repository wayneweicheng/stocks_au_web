// Integration seam: render the actual page with the user's SPY/QQQ quotes.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const ts = require('typescript');
const pageFile = path.resolve(__dirname, '../src/app/spx-map-reports/[jobId]/mapped-levels/page.tsx');
const source = fs.readFileSync(pageFile, 'utf8');
const code = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX, target: ts.ScriptTarget.ES2020 } }).outputText;
const clock = Date.parse('2026-10-22T21:15:00Z');
const states = [
  { primary_supports: [{ zone_low: 7700.3, zone_high: 7709.7, tradable_center: 7704.5 }] },
  { historical_closes: { SPX: 7700, SPY: 773.13, QQQ: 725.21, TQQQ: 72.61, NQMain: 29997.5 }, historical_close_date: '2026-10-21',
    historical_close_dates: { SPX: '2026-10-21', SPY: '2026-10-21', QQQ: '2026-10-21', TQQQ: '2026-10-21', NQMain: '2026-10-21' }, calibration_eligible: false },
  { SPY: 765.49, QQQ: 714.06 },
  'partial', 'unavailable', {}, false, '', false, null, {}, 'loading', 'loading',
];
let index = 0;
let effects = [];
const intervals = [];
const element = (type, props) => ({ type, ...props });
global.window = { setInterval: (fn, delay) => { intervals.push({ fn, delay }); return intervals.length; }, clearInterval: () => {},
  setTimeout: () => 1, clearTimeout: () => {} };
const react = { use: () => ({ jobId: 'fixture' }), useEffect: (f) => effects.push(f), useMemo: (f) => f(),
  useState: () => { const at = index++; return [states[at], (update) => { states[at] = typeof update === 'function' ? update(states[at]) : update; }]; } }; 
let quoteRequests = 0;
const requests = [];
const authenticatedFetch = async (url) => {
  requests.push(String(url));
  let payload;
  if (String(url).includes('/spx-map-extra-prices')) payload = {
    historical_closes: { NVDA: 200, SQQQ: 30 },
    historical_close_dates: { NVDA: '2026-10-21', SQQQ: '2026-10-20' },
    historical_close_source: '30m_regular_session',
  };
  else if (String(url).includes('/spx-map-live-extra-prices')) payload = { live_prices: { NVDA: 195, SQQQ: 30.5 }, status: 'partial' };
  else payload = {
    live_prices: { SPY: 765.49, QQQ: 714.06 }, sources: { SPY: 'ib_live', QQQ: 'ib_delayed' }, status: 'partial',
    fetched_at_utc: new Date(clock - (quoteRequests++ ? 10000 : 180000)).toISOString(),
  };
  return { ok: true, json: async () => payload };
};
const m = new Module(pageFile, module);
m.filename = pageFile;
m.paths = Module._nodeModulePaths(path.dirname(pageFile));
const originalRequire = m.require.bind(m);
m.require = (id) => {
  if (id === 'react') return react;
  if (id === 'react/jsx-runtime') return { jsx: element, jsxs: element, Fragment: 'fragment' };
  if (id === './calibration') {
    const file = path.resolve(path.dirname(pageFile), 'calibration.ts');
    const child = new Module(file, m);
    child._compile(ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText, file);
    return child.exports;
  }
  if (id.endsWith('authenticatedFetch')) return { authenticatedFetch };
  if (id.startsWith('../../../')) return { __esModule: true, default: id, levelReportKey: () => '', parseHtmlLevelDetails: () => ({}) };
  return originalRequire(id);
};
m._compile(code, pageFile);
const render = () => { index = 0; effects = []; return m.exports.default({ params: Promise.resolve({ jobId: 'fixture' }) }); };
const loadedMap = states[0];
const loadedMapping = states[1];
states[0] = null;
states[1] = null;
assert.doesNotThrow(() => render(), 'Initial client render must work before the map or prices load');
states[0] = loadedMap;
states[1] = loadedMapping;
let tree = render();
function collect(node, type, result = []) {
  if (Array.isArray(node)) { node.forEach(n => collect(n, type, result)); return result; }
  if (!node || typeof node !== 'object') return result;
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
  assert.equal(collect(cells[3], 'div').length, 0, `${label} must not display a fallback range`);
  assert.match(String(cells[3].children?.children || cells[3].children), /n\/a|unavailable/i);
  assert.match(String(cells[4].children.flat().join('')), /n\/a/);
  assert.equal(collect(cells[6], 'a').length, 0, `${label} must not offer orders without a live-ratio range`);
  assert.match(row.className, /amber|red/, `${label} must be highlighted`);
}
function check(tree, expected) {
  const row = rowFor(tree, 'QQQ');
  const cells = collect(row, 'td');
  const sourceText = collect(cells[5], 'span').map(span => span.children).join(' ') + cells[5].children.flat().filter(x => typeof x === 'string').join('');
  assert.match(sourceText, expected, `QQQ source was ${sourceText}`);
  if (sourceText.includes('observed QQQ/SPY ratio')) {
    const low = collect(cells[3], 'div')[0].children[0];
    assert.notEqual(low, '725.24', 'QQQ still mapped 1:1 with SPY');
  }
}
(async () => {
  // Old selected report, mismatched IB data types and an aged fetch timestamp
  // must not override the user's explicit live-price ratio rule.
  check(tree, /observed QQQ\/SPY ratio/);
  const initialQqq = rowFor(tree, 'QQQ');
  assert.match(String(collect(initialQqq, 'td')[2].children), /714\.06/);
  assert.doesNotMatch(JSON.stringify(collect(initialQqq, 'td')[2]), /IB price|freshness unverified|delayed/i);
  for (const label of ['TQQQ', 'NQMain']) checkUnavailable(tree, label);
  effects[1](); // actual stock quote effect
  await new Promise(resolve => setImmediate(resolve));
  const stockInterval = intervals.find(item => item.delay === 60000);
  assert.ok(stockInterval, 'Stock quotes must be polled from IB');
  stockInterval.fn(); // refreshed quote, same live prices, newer timestamp
  await new Promise(resolve => setImmediate(resolve));
  tree = render();
  check(tree, /observed QQQ\/SPY ratio/);
  for (const label of ['TQQQ', 'NQMain']) checkUnavailable(tree, label);

  // Available quotes but invalid SPY move: no synthetic 1x/3x range or orders.
  states[2] = { ...states[2], SPY: 773.13, TQQQ: 68.86, NQMain: 29480.25 };
  tree = render();
  for (const label of ['QQQ', 'TQQQ', 'NQMain']) checkUnavailable(tree, label);

  // All three targets get their own observed ratios when usable; futures
  // remain display-only because stock range-orders cannot trade CME futures.
  states[2].SPY = 765.49;
  tree = render();
  for (const label of ['QQQ', 'TQQQ', 'NQMain']) {
    const row = rowFor(tree, label);
    assert.match(collect(row, 'td')[5].children.flat().filter(x => typeof x === 'string').join(''), new RegExp(`observed ${label}/SPY ratio`));
    assert.ok(collect(collect(row, 'td')[3], 'div').length > 0, `${label} should have a mapped range`);
  }
  assert.equal(collect(collect(rowFor(tree, 'NQMain'), 'td')[6], 'a').length, 0);
  assert.ok(collect(collect(rowFor(tree, 'TQQQ'), 'td')[6], 'a').length > 0);

  // Losing the SPY quote invalidates every target, even when target quotes remain.
  delete states[2].SPY;
  tree = render();
  for (const label of ['QQQ', 'TQQQ', 'NQMain']) checkUnavailable(tree, label);
  // Extra symbols are collapsed and not fetched until a pane opens.
  states[2].SPY = 765.49;
  tree = render();
  const pane = collect(tree, 'details')[0];
  assert.ok(pane, 'missing collapsed more-stocks pane');
  assert.equal(pane.open, undefined, 'more-stocks pane must be closed by default');
  assert.match(collect(pane, 'summary')[0].children.join(''), /More stocks \(14\)/);
  assert.equal(collect(pane, 'td').filter(td => td.children === 'NVDA').length, 0);
  assert.equal(requests.some(url => url.includes('extra-prices')), false);
  assert.equal(requests.some(url => url.includes('live-extra-prices')), false);

  pane.onToggle({ currentTarget: { open: true } });
  tree = render();
  effects[3](); // date-bound closes
  effects[4](); // IB quotes, independent of main stocks
  await new Promise(resolve => setImmediate(resolve));
  tree = render();
  assert.ok(requests.some(url => url.includes('spx-map-extra-prices?observation_date=2026-10-21')));
  assert.ok(requests.some(url => url.includes('spx-map-live-extra-prices')));
  const nvda = rowFor(tree, 'NVDA');
  assert.match(JSON.stringify(collect(nvda, 'td')[1]), /30M.*2026-10-21/);
  assert.ok(collect(collect(nvda, 'td')[3], 'div').length > 0, 'NVDA should have mapped levels');
  const nvdaLinks = collect(collect(nvda, 'td')[6], 'a');
  assert.deepEqual(nvdaLinks.map(link => link.children), ['Buy range', 'Sell range', 'Sell put']);
  assert.match(nvdaLinks[0].href, /stock=NVDA/);
  assert.match(nvdaLinks[2].href, /action=SELL/);
  const inverse = rowFor(tree, 'SQQQ');
  const inverseCells = collect(inverse, 'td');
  assert.match(JSON.stringify(inverseCells[1]), /30M.*2026-10-20/);
  assert.match(String(inverseCells[5].children.flat().filter(x => typeof x === 'string').join('')), /observed SQQQ\/SPY ratio \(-/);
  const inverseRange = collect(inverseCells[3], 'div');
  assert.ok(inverseRange.length === 2, 'inverse ratio should yield a mapped range');
  assert.ok(Number.parseFloat(inverseRange[0].children[0]) < Number.parseFloat(inverseRange[1].children[0]));
  checkUnavailable(tree, 'SPCX'); // retain the exact symbol; never fabricate a price
  checkUnavailable(tree, 'SKHY');
  checkUnavailable(tree, 'SOXX');
  assert.equal(collect(tree, 'td').some(td => td.children === 'SOXL'), false);
  states[0].primary_resistances = [{ zone_low: 7740, zone_high: 7750, tradable_center: 7745 }];
  tree = render();
  const resistance = collect(tree, 'section').find(section => JSON.stringify(section.children).includes('Resistance'));
  const resistanceNvda = rowFor(resistance, 'NVDA');
  const sellPut = collect(collect(resistanceNvda, 'td')[6], 'a').find(link => link.children === 'Sell put');
  assert.match(sellPut.href, /action=SELL/, 'Sell put must not silently switch to Buy put on resistance');
  console.log('Live-ratio-only ranges, compact extras and safe order links: OK');
})().catch(err => { console.error(err); process.exitCode = 1; });
