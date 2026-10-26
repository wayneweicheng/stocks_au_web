const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => {
  module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 }, fileName: filename,
  }).outputText, filename);
};
const { classifyMapZones, parseStockMap, mapStockCode, mapObservationDate, mapZones, mapLineColor, mapLineWidth, reportAsAtClose, reportGeneratedTime, reportMatchesStock, reportTimeCategoryPosition } =
  require(path.join(__dirname, '../src/app/support-resistance/stockMapLevels.ts'));
const data = parseStockMap({ content: JSON.stringify({ stock_code: 'QQQ.US', as_at: '2026-04-23 14:00 Australia/Sydney',
  primary_supports: [
    { rank: 1, zone_low: 495, zone_high: 497, core_anchor_price: 496, total_score: 85, confidence: 'strong', main_evidence: ['Daily S1'] },
    { rank: 2, zone_low: 491, zone_high: 493, reference_price: 492 },
  ],
  zone_primary_supports: [{ core_anchor_price: 492, total_score: 33, confidence: 'moderate', main_evidence: ['weekly pivot'] }],
  primary_resistances: [{ zone_low: 505, zone_high: 507, total_score: 40 }],
}) });
assert.equal(mapStockCode(data), 'QQQ');
assert.equal(mapObservationDate(data), '2026-04-23');
assert.equal(mapObservationDate({ as_of_et: '2026-10-22T07:21:00-04:00', generated_at_sydney: '2026-10-25T18:24:45+11:00' }), '2026-10-22');
const supports = mapZones(data, 'support');
assert.deepEqual(supports.map((zone) => zone.score), [85, 33]);
assert.equal(supports[0].details.main_evidence[0], 'Daily S1');
assert.equal(supports[1].details.main_evidence[0], 'weekly pivot');
assert.equal(mapZones(data, 'resistance')[0].price, 506);
assert.ok(mapLineWidth(85) > mapLineWidth(33));
assert.equal(mapLineWidth(null), 2);
const brightness = (color) => color.slice(1).match(/../g).map((channel) => parseInt(channel, 16)).reduce((sum, channel) => sum + channel, 0);
for (const side of ['support', 'resistance']) {
  assert.ok(brightness(mapLineColor(side, 90)) < brightness(mapLineColor(side, 30)), `${side}: higher score must be darker`);
  assert.ok(mapLineWidth(90) > mapLineWidth(30), `${side}: higher score must be thicker`);
  assert.equal(mapLineColor(side, 0), mapLineColor(side, -20));
  assert.equal(mapLineColor(side, 100), mapLineColor(side, 120));
}
assert.match(mapLineColor('support', 75), /^#[0-9a-f]{6}$/);
assert.notEqual(mapLineColor('support', 75), mapLineColor('resistance', 75));
assert.ok(reportMatchesStock({ job_id: '1', title: 'QQQ:20260423 Australia/Sydney' }, 'QQQ'));
const october = reportGeneratedTime({ job_id: '5', title: 'QQQ:2026-10-22 21:00 Australia/Sydney' });
assert.deepEqual(october, { label: '2026-10-22 21:00 Australia/Sydney', easternWallTime: '2026-10-22T06:00:00' });
const january = reportGeneratedTime({ job_id: '6', title: 'SPY Stock Map', file_name: 'SPY:2026-01-22 21:00 Australia/Sydney' });
assert.equal(january.easternWallTime, '2026-01-22T05:00:00');
assert.equal(reportGeneratedTime({ job_id: '7', title: 'QQQ Stock Map' }), null);
assert.deepEqual(require(path.join(__dirname, '../src/app/support-resistance/stockMapLevels.ts')).mapAsOfTime(
  { as_of_et: '2026-10-22T07:21:00-04:00', as_of_sydney: '2026-10-22T22:21:00+11:00', generated_at_sydney: '2026-10-25T18:24:45+11:00' },
  { job_id: '9', title: 'QQQ:2026-10-23 22:21 Australia/Sydney' }, // structured timestamp wins over a stale label
), { label: '2026-10-22 22:21 Australia/Sydney', easternWallTime: '2026-10-22T07:21:00' });
assert.equal(reportGeneratedTime({ job_id: '8', title: 'QQQ:2026-10-04 02:30 Australia/Sydney' }), null); // DST gap
const bars = [
  { time: '2026-10-22T05:30:00' }, { time: '2026-10-22T06:00:00' }, { time: '2026-10-22T06:30:00' },
];
assert.equal(reportTimeCategoryPosition(bars, october.easternWallTime), 1);
assert.equal(reportTimeCategoryPosition(bars, '2026-10-22T06:15:00'), 1.5);
assert.equal(reportTimeCategoryPosition(bars, '2026-10-22T07:00:00'), 3);
assert.equal(reportTimeCategoryPosition(bars, '2026-10-22T05:00:00'), -0.5);
assert.deepEqual(reportAsAtClose([
  { time: '2026-10-22T05:00:00', close: 495 }, { time: '2026-10-22T05:30:00', close: 500 },
  { time: '2026-10-22T06:00:00', close: 510 }, // not completed at the 06:00 report time
], october.easternWallTime), { price: 500, barTime: '2026-10-22T05:30:00' });
assert.equal(reportAsAtClose([{ time: '2026-10-22T06:00:00', close: 510 }], october.easternWallTime), null);
const reclassified = classifyMapZones(
  [{ ...supports[0], price: 505 }, { ...supports[1], price: 499 }],
  [{ ...mapZones(data, 'resistance')[0], price: 498 }], 500,
);
assert.deepEqual(reclassified.supports.map((zone) => [zone.price, zone.sourceSide]), [[499, 'support'], [498, 'resistance']]);
assert.deepEqual(reclassified.resistances.map((zone) => [zone.price, zone.sourceSide]), [[505, 'support']]);
const tied = classifyMapZones([{ ...supports[0], price: 500 }], [{ ...mapZones(data, 'resistance')[0], price: 500 }], 500);
assert.equal(tied.supports.length, 1);
assert.equal(tied.resistances.length, 1);
assert.ok(reportMatchesStock({ job_id: '2', title: 'Other', stock_code: 'QQQ.US' }, 'QQQ'));
assert.ok(!reportMatchesStock({ job_id: '3', title: 'SPY:20260423 Australia/Sydney' }, 'QQQ'));
assert.ok(!reportMatchesStock({ job_id: '4', title: 'QQQQ:20260423 Australia/Sydney' }, 'QQQ'));
console.log('Stock Map support/resistance parsing OK');
