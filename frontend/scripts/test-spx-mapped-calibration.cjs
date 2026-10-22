const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
const Module = require('node:module');

const file = path.resolve(__dirname, '../src/app/spx-map-reports/[jobId]/mapped-levels/calibration.ts');
const { outputText } = ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS } });
const mod = new Module(file, module);
mod._compile(outputText, file);
const { liveMoveRatio, mappedFromSpy, directStockRangeHref } = mod.exports;

const ratio = liveMoveRatio(100, 99, 200, 196.8); // SPY -1%, QQQ -1.6%
assert.ok(Math.abs(ratio - 1.6) < 1e-10);
assert.ok(Math.abs(mappedFromSpy(98.8, 100, 200, ratio) - 196.16) < 1e-10);
assert.ok(Math.abs(mappedFromSpy(98.9, 100, 200, ratio) - 196.48) < 1e-10);
assert.equal(liveMoveRatio(100, 100, 200, 199), null);
assert.equal(liveMoveRatio(100, 99.95, 200, 196.8), null); // near-flat SPY
assert.equal(liveMoveRatio(100, 99, 200, 202), null); // divergence for ordinary stocks
assert.ok(Math.abs(liveMoveRatio(100, 99, 30, 30.5, true) + 1.66666666666667) < 1e-10); // inverse SQQQ
assert.equal(liveMoveRatio(100, 99, 200, 185), null); // extreme ratio
assert.equal(liveMoveRatio(null, 99, 200, 196.8), null);
for (const symbol of ['QQQ', 'TQQQ']) {
  const url = new URL(directStockRangeHref(symbol, 'Buy', 196.16, 196.48), 'http://localhost');
  assert.equal(url.searchParams.get('stock'), symbol);
  assert.equal(url.searchParams.get('start'), '196.16');
  assert.equal(url.searchParams.get('end'), '196.48');
  assert.equal(url.searchParams.has('proxy'), false);
  assert.equal(url.searchParams.has('bracket'), false);
}
assert.equal(directStockRangeHref('QQQ', 'Sell', -1, 200), '');
console.log('SPX mapped calibration and direct stock order links: OK');
