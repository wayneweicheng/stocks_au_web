// Exercise the real Stock Map report loader with mocked report and bar HTTP responses.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
const page = fs.readFileSync(path.join(__dirname, '../src/app/support-resistance/page.tsx'), 'utf8');
const ast = ts.createSourceFile('page.tsx', page, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
let loader;
function visit(node) {
  if (ts.isVariableDeclaration(node) && node.name.getText(ast) === 'loadMapReport') loader = node.initializer.arguments[0].getText(ast);
  ts.forEachChild(node, visit);
}
visit(ast);
assert.ok(loader, 'real loadMapReport callback must exist');
const js = ts.transpileModule(`const load = ${loader};`, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 }, fileName: filename,
}).outputText, filename);
const helpers = require(path.join(__dirname, '../src/app/support-resistance/stockMapLevels.ts'));
const { DEFAULT_CHART_DAYS } = require(path.join(__dirname, '../src/app/support-resistance/chartRange.ts'));
const asAt = { time: '2026-10-21T18:00:00', open: 722, high: 723, low: 721, close: 721.63, volume: 20 };
const later = { time: '2026-10-22T09:30:00', open: 730, high: 732, low: 729, close: 731, volume: 30 };
const requests = [];
let selection;
const mapRequest = { current: 1 };
const map = { stock_code: 'QQQ', as_of_et: '2026-10-21T19:19:00-04:00', as_of_sydney: '2026-10-22T10:19:00+11:00',
  primary_supports: [{ zone_low: 720, zone_high: 722, core_anchor_price: 721 }], primary_resistances: [] };
const authenticatedFetch = async (url) => {
  requests.push(url);
  const body = url.includes('/stock-map-reports/') ? { data: map } :
    { bars: url.includes('observation_date=') ? [asAt] : [asAt, later] };
  return { ok: true, json: async () => body };
};
const load = new Function('ctx', `with(ctx) { ${js}; return load; }`)({
  baseUrl: '', mapRequest, authenticatedFetch, DEFAULT_CHART_DAYS, ...helpers,
  setSelectedMapJob() {}, setMapData(value) { selection = value; }, setMapLoading() {}, setMapError() {},
});
(async () => {
  await load({ job_id: 'test', title: 'QQQ:2026-10-22 10:19 Australia/Sydney' }, 'QQQ', 1);
  assert.equal(selection.asAtClose.price, 721.63, 'as-at classification remains historical');
  assert.ok(selection.bars.some((bar) => bar.time === later.time), '30m chart should show bars after map as-at');
  assert.ok(requests.some((url) => url.includes('/chart-bars?') && !url.includes('observation_date=')), 'chart needs a separate latest-bars request');
  console.log('Stock Map as-at classification and post-as-at candles OK');
})().catch((error) => { console.error(error); process.exitCode = 1; });
