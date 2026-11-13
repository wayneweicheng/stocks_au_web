const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText, filename);
const { topLevels, reportSymbol, sortByZoneDistance, levelMidpoint, rangeOrderHref } = require('../src/app/stock-level-overview/overview.ts');

assert.equal(reportSymbol({ title: 'NVDA:2026-05-30 10:00 Australia/Sydney' }), 'NVDA');
const zone = (rank, score, low, high, anchor = (low + high) / 2) => ({ rank, total_score: score, zone_low: low, zone_high: high, core_anchor_price: anchor });
const data = { primary_supports: [zone(1, 80, 90, 92), zone(2, 95, 98, 99), zone(3, 85, 97, 98)], primary_resistances: [zone(1, 99, 102, 104), zone(2, 75, 101, 102), zone(3, 65, 110, 111)] };
const result = topLevels(data, 100);
assert.deepEqual(result.supports.map(({ zone }) => zone.score), [95, 85]);
assert.deepEqual(result.resistances.map(({ zone }) => zone.score), [99, 75]);
assert.equal(result.supports[0].distancePct, 1);
assert.equal(result.resistances[0].distancePct, 2);
assert.equal(levelMidpoint(result.supports[0].zone), 98.5);
const supportOrder = new URL(rangeOrderHref('NVDA', 'support', 98, 99), 'http://localhost');
assert.equal(supportOrder.pathname, '/range-orders');
assert.equal(supportOrder.searchParams.get('stock'), 'NVDA');
assert.equal(supportOrder.searchParams.get('side'), 'Buy');
assert.equal(supportOrder.searchParams.get('start'), '98.00');
assert.equal(supportOrder.searchParams.get('end'), '99.00');
const resistanceOrder = new URL(rangeOrderHref('NVDA', 'resistance', 102, 104), 'http://localhost');
assert.equal(resistanceOrder.searchParams.get('side'), 'Sell');
assert.equal(resistanceOrder.searchParams.get('start'), '102.00');
assert.equal(resistanceOrder.searchParams.get('end'), '104.00');
const crossed = topLevels({ primary_supports: [zone(1, 90, 101, 103)], primary_resistances: [zone(1, 80, 95, 97)] }, 100);
assert.equal(crossed.resistances[0].zone.sourceSide, 'support');
assert.equal(crossed.supports[0].zone.sourceSide, 'resistance');
assert.equal(topLevels({ primary_supports: [zone(1, 99, 99, 101)] }, 100).supports[0].distancePct, 0);
assert.equal(topLevels(data, null).supports[0].distancePct, null);
assert.equal(topLevels(data, null).supports[0].zone.score, 95);
// Even a nonstandard report anchor outside its interval must not make an outside price appear inside.
assert.equal(topLevels({ primary_supports: [zone(1, 99, 103, 105, 90)] }, 100).supports[0].distancePct, 3);
const rows = [
  { symbol: 'FAR', supports: [{ distancePct: 10 }], resistances: [{ distancePct: 0 }] },
  { symbol: 'NEAR', supports: [{ distancePct: 4 }, { distancePct: 1 }], resistances: [{ distancePct: 5 }] },
  { symbol: 'INSIDE', supports: [{ distancePct: 0 }, { distancePct: 6 }], resistances: [] },
  { symbol: 'MISSING', supports: [{ distancePct: null }], resistances: [] },
];
assert.deepEqual(sortByZoneDistance(rows, { side: 'support', direction: 'asc' }).map((row) => row.symbol), ['INSIDE', 'NEAR', 'FAR', 'MISSING']);
assert.deepEqual(sortByZoneDistance(rows, { side: 'support', direction: 'desc' }).map((row) => row.symbol), ['FAR', 'NEAR', 'INSIDE', 'MISSING']);
assert.deepEqual(sortByZoneDistance(rows, { side: 'resistance', direction: 'asc' }).map((row) => row.symbol), ['FAR', 'NEAR', 'INSIDE', 'MISSING']);
assert.deepEqual(sortByZoneDistance(rows, { side: 'resistance', direction: 'desc' }).map((row) => row.symbol), ['NEAR', 'FAR', 'INSIDE', 'MISSING']);
const page = fs.readFileSync(path.join(__dirname, '../src/app/stock-level-overview/page.tsx'), 'utf8');
assert.match(page, /stock-map-live-prices/);
assert.doesNotMatch(page, /chart-bars|MAX_STOCKS/);
assert.match(page, /Friday 8:00 a\.m\. through Sunday 8:00 p\.m\./);
assert.match(page, /IB OVERNIGHT/);
assert.match(page, /IB SMART/);
assert.match(page, /database_30m/);
assert.match(page, /Inside zone · 0\.00% away/);
assert.match(page, /Mid \{formatPrice\(midpoint\)\}/);
assert.match(page, /rangeOrderHref\(symbol, side, zone\.range_low, zone\.range_high\)/);
assert.match(page, /target="_blank" rel="noopener noreferrer"/);
assert.match(page, /Open \$\{sideLabel\.toLowerCase\(\)\} range order for \$\{symbol\}/);
assert.match(page, /aria-sort=/);
console.log('Stock overview uses session-aware prices and sorts all reports by top-2 zone proximity');
