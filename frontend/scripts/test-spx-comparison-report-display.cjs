const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 }, fileName: filename,
}).outputText, filename);
const { spxComparisonReportDates, spxComparisonReportTitle } = require('../src/app/spx-map-reports/comparisonReportDisplay.ts');
const report = { title: 'SPX comparison', observation_date: '2026-11-06', job_id: 'abc123' };
const dates = spxComparisonReportDates(report, '# Comparison\nD1 trading date: 2026-11-06\nD2 trading date: 2026-11-05');
assert.deepEqual(dates, { d1: '2026-11-06', d2: '2026-11-05' });
assert.equal(spxComparisonReportTitle(dates), 'D1 2026-11-06 vs D2 2026-11-05');
assert.deepEqual(spxComparisonReportDates({ d1_date: '2026-11-06', d2_date: '2026-11-05' }), dates);
const reportWithCombinedDateLines = spxComparisonReportDates(
  { observation_date: '2026-11-09' },
  '# SPX Map Comparison — 2026-11-09 vs 2026-11-06\\nD1 is the selected trading date, 2026-11-09; D2 is the immediately preceding XNYS session, 2026-11-06.'
);
assert.deepEqual(reportWithCombinedDateLines, { d1: '2026-11-09', d2: '2026-11-06' });
assert.deepEqual(spxComparisonReportDates({ label: 'SPX:2026-11-09:2026-11-06' }), { d1: '2026-11-09', d2: '2026-11-06' });
const page = fs.readFileSync(path.join(__dirname, '../src/app/spx-map-reports/SpxMapComparisonWorkspace.tsx'), 'utf8');
assert.match(page, /grid gap-2 sm:grid-cols-2 xl:grid-cols-3/);
assert.match(page, /spxComparisonReportTitle\(/);
assert.match(page, /api<AnyObject>\("\/spx-map-comparison-preview"/);
assert.match(page, /\/api\/spx-map-comparison\/jobs\/\$\{encodeURIComponent\(id\)\}\/report/);
console.log('SPX comparison viewer derives D1/D2 dates and renders selectable report cards');
