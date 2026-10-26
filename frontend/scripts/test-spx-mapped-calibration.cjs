const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
const Module = require('node:module');

const file = path.resolve(__dirname, '../src/app/spx-map-reports/[jobId]/mapped-levels/calibration.ts');
const { outputText } = ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS } });
const mod = new Module(file, module);
mod._compile(outputText, file);
const { assessLiveMoveRatio, liveMoveRatio, liveMoveSpread, mappedFromSpy, mappedFromSpySpread, mappedFromLeveragedParent, shouldUseMoveRatio, directStockRangeHref } = mod.exports;

const ratio = liveMoveRatio(100, 99, 200, 196.8); // SPY -1%, QQQ -1.6%
assert.ok(Math.abs(ratio - 1.6) < 1e-10);
assert.ok(Math.abs(mappedFromSpy(98.8, 100, 200, ratio) - 196.16) < 1e-10);
assert.ok(Math.abs(mappedFromSpy(98.9, 100, 200, ratio) - 196.48) < 1e-10);
assert.equal(mappedFromLeveragedParent(99, 100, 200), 194);
assert.equal(mappedFromLeveragedParent(101, 100, 200), 206);
assert.equal(liveMoveRatio(100, 100, 200, 199), null);
assert.ok(Math.abs(liveMoveRatio(100, 99.95, 200, 196.8) - 32) < 1e-10); // extreme but finite
// Small SPY moves can produce large observed ratios; flag the risk without
// discarding a usable mapped range or its stock/option actions.
const observedRatio = ((707.45 / 704.56) - 1) / ((764.4 / 764.03) - 1);
assert.ok(Math.abs(liveMoveRatio(764.03, 764.4, 704.56, 707.45) - observedRatio) < 1e-10);
const assessment = assessLiveMoveRatio(764.03, 764.4, 704.56, 707.45);
assert.equal(assessment.blockedReason, null);
assert.match(assessment.riskReason, /SPY \+0\.048%.*target \+0\.410%.*ratio .*8\.4.*SPY move below 0\.20%; ratio above 6×/);
const customerRatio = liveMoveRatio(764.03, 764.15, 704.56, 707.15);
assert.equal(customerRatio.toFixed(2), '23.41');
const spread = (707.15 / 704.56 - 1) - (764.15 / 764.03 - 1);
assert.ok(Math.abs(liveMoveSpread(764.03, 764.15, 704.56, 707.15) - spread) < 1e-10);
assert.ok(Math.abs(mappedFromSpySpread(764.15, 764.03, 704.56, spread) - 707.15) < 1e-10,
  'at the live SPY quote, the spread mapping must equal the live target quote');
assert.ok(Math.abs(mappedFromSpySpread(765.15, 764.03, 704.56, spread) -
  (707.15 + 704.56 / 764.03)) < 1e-10, 'a one-point SPY move uses an additive percentage-point shift');
assert.equal(liveMoveSpread(100, 100, 30, 30.3).toFixed(2), '0.01');
// SPY -0.2%, QQQ +0.1%: use +0.3 percentage points, added to SPY's
// projected low and high percentage moves before applying QQQ's close.
const divergentSpread = liveMoveSpread(100, 99.8, 200, 200.2);
assert.ok(Math.abs(divergentSpread - 0.003) < 1e-10);
assert.ok(Math.abs(mappedFromSpySpread(99, 100, 200, divergentSpread) - 198.6) < 1e-10);
assert.ok(Math.abs(mappedFromSpySpread(101, 100, 200, divergentSpread) - 202.6) < 1e-10);
assert.equal(shouldUseMoveRatio(-0.002, 0.001), false, 'opposite directions always use difference');
assert.equal(shouldUseMoveRatio(-0.004, 0.001), false, 'opposite directions use difference even for large SPY moves');
assert.equal(shouldUseMoveRatio(0.004, -0.001), false, 'reverse divergence also uses difference');
assert.equal(shouldUseMoveRatio(0.002, 0.001), false, 'exactly 0.20% uses difference');
assert.equal(shouldUseMoveRatio(-0.0021, -0.001), false, 'small target move uses difference even with strong SPY');
assert.equal(shouldUseMoveRatio(0.0021, 0.001), false);
assert.equal(shouldUseMoveRatio(0.0021, 0.002), false, 'target exactly at 0.20% uses difference');
assert.equal(shouldUseMoveRatio(-0.0021, -0.0021), true, 'both same-sign moves beyond 0.20% use ratio');
assert.equal(shouldUseMoveRatio(0.0021, 0.0021), true);
assert.equal(shouldUseMoveRatio(0.0021, 0), false, 'flat target uses difference');
assert.equal(shouldUseMoveRatio(0, 0.001), false);
assert.equal(liveMoveRatio(100, 99, 200, 202), null); // divergence for ordinary stocks
assert.ok(Math.abs(liveMoveRatio(100, 99, 30, 30.5, true) + 1.66666666666667) < 1e-10); // inverse SQQQ
assert.ok(Math.abs(liveMoveRatio(100, 99, 200, 185) - 7.5) < 1e-10); // extreme ratio still actionable
assert.match(assessLiveMoveRatio(100, 100, 200, 199).blockedReason, /SPY has not moved/);
assert.match(assessLiveMoveRatio(100, 99, 200, 202).blockedReason, /opposite directions/);
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
