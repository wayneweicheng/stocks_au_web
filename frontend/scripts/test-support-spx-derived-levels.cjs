const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 }, fileName: filename,
}).outputText, filename);
const { mapZones } = require(path.join(__dirname, '../src/app/support-resistance/stockMapLevels.ts'));
const { spxInstrumentForCode, deriveSpxZones } = require(path.join(__dirname, '../src/app/support-resistance/spxDerivedLevels.ts'));
const source = { primary_resistances: [{ rank: 1, zone_low: 7721.814925333334, zone_high: 7729.7034079999985,
  reference_price: 7723.8175, total_score: 51, confidence: 'moderate confluence',
  option_validation: { oi_contracts: 17667, wall_type: 'magnet/pin' } }] };
const zones = mapZones(source, 'resistance');
const closes = { SPX: 7721.02, ESMain: 7752.82, SPY: 769.36, QQQ: 610, SPXL: 185, TQQQ: 55, SOXL: 45, SOXX: 225 }; 
const historical_close_dates = Object.fromEntries(Object.keys(closes).map((key) => [key, '2026-10-29']));
const snapshot = { historical_closes: closes, historical_close_dates, calibration_eligible: true };
const quotes = { SPY: 765, QQQ: 600, SOXL: 44, SOXX: 223 }; 
assert.equal(spxInstrumentForCode('SPX'), 'SPX');
assert.equal(spxInstrumentForCode('esmain'), 'ESMain');
assert.equal(spxInstrumentForCode('spY_d'), 'SPY_D');
assert.equal(spxInstrumentForCode('QQQ_D'), 'QQQ_D');
assert.equal(spxInstrumentForCode('SPXL_D'), 'SPXL_D');
assert.equal(spxInstrumentForCode('TQQQ_D'), 'TQQQ_D');
assert.equal(spxInstrumentForCode('SOXL_D'), 'SOXL_D');
assert.equal(spxInstrumentForCode('SOXX_D'), 'SOXX_D');
assert.equal(spxInstrumentForCode('SPY'), null); // Plain SPY keeps Stock Map behavior.
const es = deriveSpxZones(zones, 'ESMain', snapshot, {});
assert.ok(es);
assert.ok(Math.abs(es.zones[0].range_low - (7721.814925333334 + 31.8)) < 0.00001);
assert.ok(Math.abs(es.zones[0].range_high - (7729.7034079999985 + 31.8)) < 0.00001);
assert.equal(es.zones[0].score, 51);
assert.equal(es.zones[0].details.option_validation.oi_contracts, 17667); // SPX evidence, not ES contracts.
const spy = deriveSpxZones(zones, 'SPY_D', snapshot, {});
assert.ok(Math.abs(spy.zones[0].range_low - 769.36 * (1 + (zones[0].range_low / 7721.02 - 1))) < 0.000001);
for (const [code, mapped, close] of [['ESMain', es, 7752.82], ['SPY_D', spy, 769.36], ['QQQ_D', deriveSpxZones(zones, 'QQQ_D', snapshot, quotes), 610],
  ['SPXL_D', deriveSpxZones(zones, 'SPXL_D', snapshot, {}), 185], ['TQQQ_D', deriveSpxZones(zones, 'TQQQ_D', snapshot, quotes), 55],
  ['SOXL_D', deriveSpxZones(zones, 'SOXL_D', snapshot, quotes), 45], ['SOXX_D', deriveSpxZones(zones, 'SOXX_D', snapshot, quotes), 225]]) {
  assert.equal(mapped.zones[0].details.mapping_selected_close, close, `${code} must use its own selected close`);
  assert.equal(mapped.zones[0].details.mapping_selected_close_date, '2026-10-29');
  assert.equal(mapped.zones[0].details.mapped_anchor, mapped.zones[0].price);
  assert.ok(Math.abs(mapped.zones[0].details.mapped_anchor_vs_selected_close_pct - (mapped.zones[0].price / close - 1) * 100) < 0.000001);
}
const qqq = deriveSpxZones(zones, 'QQQ_D', snapshot, quotes);
assert.ok(qqq);
const ratio = (600 / 610 - 1) / (765 / 769.36 - 1);
const spyLow = spy.zones[0].range_low;
assert.ok(Math.abs(qqq.zones[0].range_low - 610 * (1 + (spyLow / 769.36 - 1) * ratio)) < 0.000001);
const spxl = deriveSpxZones(zones, 'SPXL_D', snapshot, {});
assert.ok(Math.abs(spxl.zones[0].range_low - 185 * (1 + 3 * (spyLow / 769.36 - 1))) < 0.000001);
const tqqq = deriveSpxZones(zones, 'TQQQ_D', snapshot, quotes);
assert.ok(Math.abs(tqqq.zones[0].range_low - 55 * (1 + 3 * (qqq.zones[0].range_low / 610 - 1))) < 0.000001);
const weakMove = { SPY: 769.5, QQQ: 610.5 };
const spreadMapped = deriveSpxZones(zones, 'QQQ_D', snapshot, weakMove);
const spread = (610.5 / 610 - 1) - (769.5 / 769.36 - 1);
assert.ok(Math.abs(spreadMapped.zones[0].range_low - 610 * (1 + (spyLow / 769.36 - 1) + spread)) < 0.000001);
assert.ok(spreadMapped.source.includes('spread'));
const soxl = deriveSpxZones(zones, 'SOXL_D', snapshot, quotes);
const soxx = deriveSpxZones(zones, 'SOXX_D', snapshot, quotes);
assert.ok(soxl.source.includes('SOXL/SPY'));
assert.ok(soxx.source.includes('SOXX/SPY'));
assert.ok(Math.abs(soxl.zones[0].range_low - 45 * (1 + (spyLow / 769.36 - 1) * ((44 / 45 - 1) / (765 / 769.36 - 1)))) < 0.000001);
assert.ok(Math.abs(soxx.zones[0].range_low - 225 * (1 + (spyLow / 769.36 - 1) * ((223 / 225 - 1) / (765 / 769.36 - 1)))) < 0.000001);
assert.equal(deriveSpxZones(zones, 'SOXX_D', snapshot, { SPY: 765 }), null);
assert.ok(deriveSpxZones(zones, 'SOXL_D', { ...snapshot, calibration_eligible: false }, quotes), 'as-of bar mapping is valid even when selected date is not live-calibration eligible');
assert.equal(deriveSpxZones(zones, 'SOXX_D', { ...snapshot, historical_close_dates: { ...historical_close_dates, SOXX: '2026-10-28' } }, quotes), null);
assert.equal(deriveSpxZones(zones, 'QQQ_D', snapshot, {}), null); // No invented QQQ calibration.
assert.equal(deriveSpxZones(zones, 'TQQQ_D', snapshot, {}), null);
assert.equal(deriveSpxZones(zones, 'ESMain', { ...snapshot, historical_close_dates: { ...historical_close_dates, ESMain: '2026-10-28' } }, {}), null);
assert.equal(deriveSpxZones(zones, 'SPY_D', { ...snapshot, historical_close_dates: { ...historical_close_dates, SPY: '2026-10-28' } }, {}), null);
console.log('ES, SPY, QQQ, leveraged and semiconductor SPX-map zones follow source mapping and fail closed');
