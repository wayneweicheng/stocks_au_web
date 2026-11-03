// Deterministic component-level reproduction of missing details below HTML top rows.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
const React = require('react');
const { renderToStaticMarkup } = require('react-dom/server');

require.extensions['.tsx'] = (module, filename) => {
  const source = fs.readFileSync(filename, 'utf8');
  const javascript = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX, target: ts.ScriptTarget.ES2022 },
    fileName: filename,
  }).outputText;
  module._compile(javascript, filename);
};
const { default: Component, parseHtmlLevelDetails } = require(path.join(__dirname, '../src/app/components/MappedLevelReportDetails.tsx'));
const zone = {
  rank: 5, zone_low: 7652.5, zone_high: 7657.5, reference_price: 7655,
  total_score: 34, raw_confluence_score: 34, execution_relevance_score: 12.5,
  score_components: { price_structure_score: 18, spxw_option_score: 16, spy_confirmation_score: 0, expected_move_score: 0, vix_confirmation_score: 0 },
  main_evidence: ['Daily S1 7655.00'], distance_from_execution_reference: -23,
  distance_from_last_close_pct: -0.48, hold_condition: '守住 7652.50–7657.50',
  failure_or_flip_condition: '跌破后翻转为压力',
  option_validation: { matched: true, label: 'SPXW put wall + GEX', strike: 7655,
    expiry_bucket: '0DTE', oi_contracts: 2164, gex_magnitude: 524941165 },
};
for (const rank of [4, 5]) {
  const html = renderToStaticMarkup(React.createElement(Component, { side: 'support', rank, zone, detail: undefined }));
  assert.match(html, /SPXW put wall \+ GEX/);
  assert.match(html, /OI 2,164/);
  assert.match(html, /524,941,165/);
  assert.match(html, /Level details \(JSON; not in compact HTML table\)/);
  assert.match(html, new RegExp(`S${rank}`));
  assert.match(html, /Score breakdown/);
  assert.match(html, /Raw confluence: 34\.0/);
}
const htmlFirst = renderToStaticMarkup(React.createElement(Component, {
  side: 'support', rank: 1, zone,
  detail: { key: 'S1', level: 'S1', areaReference: 'HTML first-row reference',
    distanceToExecution: '', distanceToPreviousClose: '', executionStrength: '',
    mainBasis: '', optionVerification: 'HTML first-row option', behavior: '' },
}));
assert.match(htmlFirst, /HTML report level details/);
assert.doesNotMatch(htmlFirst, /HTML first-row option/);
assert.match(htmlFirst, /SPX 7,655\.00/);
assert.doesNotMatch(htmlFirst, /JSON; not in compact HTML table/);
const stock = renderToStaticMarkup(React.createElement(Component, { side: 'support', rank: 2, instrument: 'stock',
  detail: { key: 'S2', level: 'S2', optionVerification: 'SPX 700.00', areaReference: 'MID 700' },
  zone: { zone_low: 695, zone_high: 705, reference_price: 699, reference_price_method: 'weighted sources',
    core_anchor_inputs: ['daily pivot', 'option wall'], boundary_basis: { mathematical: [698, 700], system: [695, 705] },
    distance_from_last_close_pct: -2.1, distance_from_last_close_pct_basis: 'previous completed daily close',
    distance_from_execution_reference_pct: -1.3, distance_from_execution_reference_pct_basis: 'execution reference',
    option_validation: { matched: true, option_underlying_symbol: 'QQQ', option_price_level: 700,
      spx_price_level: null, label: 'put wall', expiry_dates: ['2026-04-24'], expiry_bucket: 'next session',
      observation_date: '2026-04-23', stale: true, gex_magnitude: -123 },
    hold_condition: 'hold 695', failure_or_flip_condition: 'below 695', total_score: 31 },
}));
assert.match(stock, /QQQ 700\.00 put wall/);
assert.doesNotMatch(stock, /SPX 700\.00|MID 700/);
for (const expected of ['Expiries 2026-04-24', 'Bucket next session', 'Observed 2026-04-23', 'Stale: yes',
  'Core reference anchor (not zone midpoint)', '699.00', 'weighted sources', 'previous completed daily close',
  'execution reference', 'hold 695', 'below 695', 'size only, not direction']) assert.ok(stock.includes(expected), expected);
const noOption = renderToStaticMarkup(React.createElement(Component, { side: 'resistance', rank: 5,
  zone: { zone_low: 7700, zone_high: 7710, total_score: 12 }, detail: undefined }));
assert.doesNotMatch(noOption, /OI 2,164|524,941,165/);
const derived = renderToStaticMarkup(React.createElement(Component, { side: 'support', rank: 7, instrument: 'spx',
  spxLastClose: 7721.02, detail: undefined,
  zone: { zone_low: 7652.5, zone_high: 7659.06, reference_price: 7655.19,
    distance_from_last_close_pct: -0.85, main_evidence: ['Daily S3 7655.97'],
    derived_instrument: 'QQQ_D', mapped_zone_low: 697.9827, mapped_zone_high: 698.5798,
    mapped_anchor: 698.2276, mapping_selected_close: 704.47,
    mapping_selected_close_date: '2026-10-30', mapped_anchor_vs_selected_close_pct: -0.885 } }));
const derivedSummary = derived.match(/<div class="font-medium[^\"]*">([^<]*)<\/div>/)?.[1] || "";
assert.match(derivedSummary, /QQQ_D 698\.23 \(-0\.89%\) vs 30M close 704\.47 \(2026-10-30\)/);
assert.doesNotMatch(derivedSummary, /前收 7,721\.02/);

// Minimal DOMParser double exercising the actual parser against two report tables.
// The complete audit table must supply the levels missing from the compact table.
global.DOMParser = class {
  parseFromString(input) {
    const tables = [...input.matchAll(/<table[^>]*>([\s\S]*?)<\/table>/g)].map((tableMatch) => {
      const table = { querySelectorAll(selector) { return selector === 'tr' ? this.rows : []; } };
      table.rows = [...tableMatch[1].matchAll(/<tr[^>]*>([\s\S]*?)<\/tr>/g)].map((rowMatch) => ({
        closest() { return table; },
        get textContent() { return this.querySelectorAll('th,td').map((cell) => cell.textContent).join(' '); },
        querySelectorAll() {
          return [...rowMatch[1].matchAll(/<(?:th|td)[^>]*>([\s\S]*?)<\/(?:th|td)>/g)]
            .map((cellMatch) => ({ textContent: cellMatch[1].replace(/<[^>]*>/g, '') }));
        },
      }));
      return table;
    });
    return { querySelectorAll(selector) { return selector === 'table tr' ? tables.flatMap((table) => table.rows) : []; } };
  }
};
const headers = '<tr><th>等级</th><th>区域</th><th>距执行参考</th><th>距前收</th><th>执行相关</th><th>主要依据</th><th>期权验证</th><th>守住</th></tr>';
const row = (id) => `<tr><td>${id}</td><td>7655</td><td>-2</td><td>-0.48%</td><td>12 / 34</td><td>pivot</td><td>${id} put wall</td><td>hold</td></tr>`;
const compact = `<table>${headers}${['R1','R2','R3','R4','S1','S2','S3','S4'].map(row).join('')}</table>`;
const audit = `<table>${headers}${['R1','R2','R3','R4','R5','R6','S1','S2','S3','S4','S5','S6'].map(row).join('')}</table>`;
const parsed = parseHtmlLevelDetails(compact + audit);
assert.equal(Object.keys(parsed).length, 12);
assert.equal(parsed.R5.optionVerification, 'R5 put wall');
assert.equal(parsed.S6.optionVerification, 'S6 put wall');
console.log('PASS: all mapped levels retain HTML or genuine JSON detail; no fabricated option evidence');
