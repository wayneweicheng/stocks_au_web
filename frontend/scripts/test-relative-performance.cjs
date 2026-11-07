const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 }, fileName: filename,
}).outputText, filename);
const { analyzeRelativePerformance, rankLivePerformance, DEFAULT_RELATIVE_SYMBOLS } = require('../src/app/relative-performance/relativePerformance.ts');
const { easternToday, defaultHistoryStart, historyRangeError } = require('../src/app/relative-performance/dateRange.ts');
assert.ok(DEFAULT_RELATIVE_SYMBOLS.includes('BAC'));
assert.ok(!DEFAULT_RELATIVE_SYMBOLS.includes('GS'));
assert.equal(easternToday(new Date('2026-11-07T01:00:00Z')), '2026-11-06');
assert.equal(defaultHistoryStart('2026-11-06'), '2026-11-02');
assert.equal(historyRangeError('2026-11-02', '2026-11-06'), null);
assert.equal(historyRangeError('2026-11-07', '2026-11-06'), 'End date must be on or after start date.');
assert.equal(historyRangeError('2026-10-01', '2026-11-06'), 'Select at most 30 calendar days.');
assert.ok(historyRangeError('2026-02-30', '2026-03-01'));
const page = fs.readFileSync(require('node:path').join(__dirname, '../src/app/relative-performance/page.tsx'), 'utf8');
assert.match(page, /type="date" value=\{startDate\}/);
assert.match(page, /type="date" value=\{endDate\}/);
assert.match(page, /start_date: startDate, end_date: endDate/);

const bars = (start, closes) => closes.map((close, index) => ({
  time: new Date(Date.UTC(2026, 10, 3, 15, index * 5)).toISOString(),
  open: close, high: close, low: close, close, volume: 1000,
}));
const input = {
  ESMain: bars(0, [100, 100.1, 100.2, 100.3, 100.4, 100.5, 100.6]),
  SPY: bars(0, [100, 100.1, 100.2, 100.3, 100.4, 100.5, 100.6]),
  QQQ: bars(0, [100, 100.2, 100.4, 100.6, 100.8, 101, 101.2]),
  SOXX: bars(0, [100, 100.2, 100.4, 100.6, 100.8, 101, 101.2]),
  MSFT: bars(0, [100, 100.05, 100.1, 100.15, 100.2, 100.25, 100.3]),
  AMZN: bars(0, [100, 100.05, 100.1, 100.15, 100.2, 100.25, 100.3]),
  AMD: bars(0, [100, 99.9, 99.8, 99.7, 99.6, 99.5, 99.4]),
  NVDA: bars(0, [100, 99.9, 99.8, 99.7, 99.6, 99.5, 99.4]),
  MU: bars(0, [100, 99.9, 99.8, 99.7, 99.6, 99.5, 99.4]),
  SNDK: bars(0, [100, 99.9, 99.8, 99.7, 99.6, 99.5, 99.4]),
};
const result = analyzeRelativePerformance(input, '5M');
assert.equal(result.rows.find((row) => row.symbol === 'QQQ').changePct, 1.2);
assert.equal(result.rows.find((row) => row.symbol === 'QQQ').last30mPct, 1.2);
assert.equal(result.divergence?.kind, 'ai_underperformance');
assert.equal(result.divergence?.underperformingCount, 6);
assert.equal(analyzeRelativePerformance({ SPY: bars(0, [100]) }, '5M').divergence, null);
const ranked = rankLivePerformance(result.rows, { QQQ: { price: 103 }, SPY: { price: 101.5 } });
assert.deepEqual(ranked.map((row) => [row.symbol, row.rank]), [["QQQ", 1], ["SPY", 2]]);
console.log('Relative performance normalization and deterioration alert: OK');
