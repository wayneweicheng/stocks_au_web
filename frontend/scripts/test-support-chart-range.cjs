const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 }, fileName: filename,
}).outputText, filename);
const { CHART_RANGE_OPTIONS, DEFAULT_CHART_DAYS, chartRangeParams } = require(path.join(__dirname, '../src/app/support-resistance/chartRange.ts'));
assert.deepEqual(CHART_RANGE_OPTIONS, [3, 5, 8, 10, 20, 30, 60]);
assert.deepEqual(DEFAULT_CHART_DAYS, { '30m': 20, '5m': 5 });
const calc = chartRangeParams({ stockCode: 'QQQ', timeframe: '30m', days: 60, source: 'calculated', observationDatetime: '2026-05-01T14:00:00' });
assert.equal(calc.get('lookback_days'), '60');
assert.equal(calc.get('observation_datetime'), '2026-05-01T14:00:00');
const saved = chartRangeParams({ stockCode: 'QQQ', timeframe: '5m', days: 8, source: 'database', mapAsOfUtc: '2026-05-01T15:00:00' });
assert.equal(saved.get('timeframe'), '5M');
assert.equal(saved.get('end_inclusive'), 'true');
assert.equal(saved.get('lookback_days'), '8');
const stockMap = chartRangeParams({ stockCode: 'QQQ', timeframe: '5m', days: 5, source: 'stock-map', observationDate: '2026-10-21' });
assert.equal(stockMap.has('observation_date'), false, 'map chart range must never inherit the historical classification cutoff');
assert.equal(chartRangeParams({ stockCode: 'QQQ', timeframe: '30m', days: 31, source: 'stock-map' }), null);
assert.equal(chartRangeParams({ stockCode: 'QQQ', timeframe: '5m', days: 5, source: 'database' }), null);
const page = fs.readFileSync(path.join(__dirname, '../src/app/support-resistance/page.tsx'), 'utf8');
assert.match(page, /setChartDays\(\(current\) => \(\{ \.\.\.current, \[chartTimeframe\]: Number\(event\.target\.value\) \}\)\)/);
assert.match(page, /timeframe: chartTimeframe, days: selectedDays/);
assert.match(page, /fetchedChartBars\.days === selectedDays/);
assert.match(page, /lookback_days: String\(DEFAULT_CHART_DAYS\["30m"\]\)/);
console.log('Chart windows and independent historical cutoffs: OK');
