const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => {
  module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 }, fileName: filename,
  }).outputText, filename);
};
const { parseSpxMap, spxReportReference, spxOptionObservationDate, spxOptionPair, spxOptionRangeForInstrument } = require(path.join(__dirname, '../src/app/support-resistance/spxMapLevels.ts'));
const { mapZones, classifyMapZones } = require(path.join(__dirname, '../src/app/support-resistance/stockMapLevels.ts'));
const { effectivePriceForSpxInstrument } = require(path.join(__dirname, '../src/app/support-resistance/spxDerivedLevels.ts'));
const { spxExpiryRangeShape } = require(path.join(__dirname, '../src/app/support-resistance/chartLayout.ts'));
const report = parseSpxMap({ data: { content: {
  as_of_et: '2026-10-30T06:05:00-04:00', reference_spx: 7721.02, execution_reference_spx: 7721.02,
  primary_supports: [], primary_resistances: [{ rank: 1, zone_low: 7721.814925333334,
    zone_high: 7729.703407999999, reference_price: 7723.8175, total_score: 51,
    confidence: 'moderate confluence', level_confidence: 'SPY-confirmed',
    main_evidence: ['Weekly R1', 'SPXW 7725 next_weekly'],
    option_validation: { strike: 7725, spx_price_level: 7725, wall_type: 'magnet/pin',
      oi_contracts: 17667, expiry_dates: ['2026-11-03'], absolute_gex_at_strike: 2770192045 },
  }],
} } });
assert.ok(report);
assert.equal(spxReportReference(report), 7721.02);
assert.equal(spxOptionObservationDate({ expected_moves: [{ data_timestamps: ['2026-11-02T00:00:00-05:00', '2026-11-02T00:00:00-05:00'] }] }, '2026-11-03'), '2026-11-02');
const effective = { SPX: 7644.2, SPY: 762.03, QQQ: 709.6, SPXL: 278.4, TQQQ: 64.2, SOXL: 34.5, SOXX: 214.2, ESMain: 7676 };
assert.equal(effectivePriceForSpxInstrument('SPX', effective), 7644.2);
assert.equal(effectivePriceForSpxInstrument('SPY_D', effective), 762.03);
assert.equal(effectivePriceForSpxInstrument('QQQ_D', effective), 709.6);
assert.equal(effectivePriceForSpxInstrument('SPXL_D', effective), 278.4);
assert.equal(effectivePriceForSpxInstrument('TQQQ_D', effective), 64.2);
assert.equal(effectivePriceForSpxInstrument('SOXL_D', effective), 34.5);
assert.equal(effectivePriceForSpxInstrument('SOXX_D', effective), 214.2);
assert.equal(effectivePriceForSpxInstrument('ESMain', effective), 7676);
assert.equal(effectivePriceForSpxInstrument('QQQ_D', { QQQ: null }), null);
const zones = mapZones(report, 'resistance');
const effectiveSpxZones = classifyMapZones(mapZones(report, 'support'), zones, effectivePriceForSpxInstrument('SPX', effective));
assert.equal(effectiveSpxZones.supports.length, 0);
assert.equal(effectiveSpxZones.resistances.length, 1, 'SPX levels are classified against SPX equivalent, not report reference');
assert.equal(zones.length, 1);
assert.equal(zones[0].range_low, 7721.814925333334);
assert.equal(zones[0].range_high, 7729.703407999999);
assert.equal(zones[0].price, 7723.8175);
assert.equal(zones[0].score, 51);
assert.equal(zones[0].details.option_validation.oi_contracts, 17667);
assert.equal(classifyMapZones([], zones, 7721.02).resistances.length, 1);
assert.equal(classifyMapZones([], zones, 7725).supports.length, 1, 'levels below live price reclassify as support');
assert.equal(classifyMapZones([], zones, 7720).resistances.length, 1, 'levels above live price reclassify as resistance');
assert.equal(parseSpxMap({ content: { ticker: 'QQQ', primary_resistances: zones } }), null);
const pair = { source: 'StockDB_US.StockData.v_OptionDelayedQuote_V2', observation_date: '2026-10-30',
  spot_reference_from_d1: 7721.02, option_rows: [
    { symbol: 'SPXW', right: 'C', observation_date: '2026-10-30', expiry: '2026-10-30', strike: 7720, price: 23.5, price_source: 'bid_ask_mid' },
    { symbol: 'SPXW', right: 'P', observation_date: '2026-10-30', expiry: '2026-10-30', strike: 7720, price: 19.25, price_source: 'last' },
  ] };
assert.equal(spxOptionPair(pair, '2026-10-30').premium, 42.75);
assert.equal(spxOptionPair(pair, '2026-10-30').strike, 7720);
assert.deepEqual(spxOptionRangeForInstrument(spxOptionPair(pair, '2026-10-30'), 'SPX', 25), { low: 7678.27, high: 7763.77 });
assert.deepEqual(spxOptionRangeForInstrument(spxOptionPair(pair, '2026-10-30'), 'ESMain', 25), { low: 7703.27, high: 7788.77 });
assert.equal(spxOptionRangeForInstrument(spxOptionPair(pair, '2026-10-30'), 'ESMain', null), null);
assert.equal(spxOptionPair({ ...pair, observation_date: '2026-10-29' }, '2026-10-30'), null);
assert.equal(spxOptionPair({ ...pair, option_rows: [pair.option_rows[0]] }, '2026-10-30'), null);
assert.equal(spxOptionPair({ ...pair, option_rows: [pair.option_rows[0], { ...pair.option_rows[1], symbol: 'SPY' }] }, '2026-10-30'), null);
assert.equal(spxOptionPair({ ...pair, option_rows: [pair.option_rows[0], { ...pair.option_rows[1], expiry: '2026-11-03' }] }, '2026-10-30'), null);
const expiryBand = spxExpiryRangeShape({ low: 7590.78, high: 7686.68 });
assert.deepEqual([expiryBand.y0, expiryBand.y1], [7590.78, 7686.68]);
assert.equal(expiryBand.type, 'rect');
const page = fs.readFileSync(path.join(__dirname, '../src/app/support-resistance/page.tsx'), 'utf8');
assert.ok(page.includes('const reportType = isSpx ? "spx-map" : "stock-map"'));
assert.ok(page.includes('/api/${reportType}-reports/'));
assert.ok(page.includes('/api/support-resistance/spx-map-options'));
assert.ok(page.includes('spxOptionObservationDate(map, observationDate)'));
assert.ok(page.includes('spxExpiryRangeShape(spxAtmRange)'));
assert.ok(page.includes('effectivePriceForSpxInstrument(spxInstrument, snapshot.effective_prices)'));
assert.ok(page.includes('matchedEsBasis(snapshot)'));
assert.ok(page.includes('spxOptionReference = spxInstrument === "SPX" ? effectivePrice'));
assert.ok(page.includes('spxEsMainPrice = effectivePrice'));
assert.ok(page.includes('spxOptionRangeForInstrument(mapData.spxOptions, mapData.stockCode, mapData.spxEsBasis)'));
assert.ok(page.includes('ESMain translated range'));
assert.ok(page.includes('formatSpxPriceWithEs(zone.range_low, stock.spxEsBasis)'));
assert.ok(page.includes('formatSpxPriceForDate(mapData.spxOptions.strike, mapData.spxEsBasis, mapData.spxEsBasisDate'));
assert.ok(page.includes('formatLevelPrice(zone.range_high)'));
assert.ok(page.includes('ESMain n/a (matched ES−SPX basis unavailable)'));
assert.ok(page.includes('isMobileViewport ? "100%"'));
assert.ok(page.includes('setChartDays((current) => ({ ...current, "30m": 5 }))'));
assert.ok(page.includes('Math.round(zone.score)'));
assert.ok(page.includes('stock.reportType === "stock-map" ? <LevelActions'));
assert.ok(page.includes('Source SPX'));
assert.ok(page.includes('Mapped reference anchor (vs selected close)'));
assert.ok(page.includes('mapping_selected_close_date'));
const detailSource = fs.readFileSync(path.join(__dirname, '../src/app/components/MappedLevelReportDetails.tsx'), 'utf8');
assert.ok(detailSource.includes('observationDate === spxEsBasisDate'));
assert.ok(detailSource.includes('formatSpxPrice(strike, optionEsBasis)'));
assert.ok(detailSource.includes('interval(zone.zone_low, zone.zone_high, spxEsBasis)'));
assert.ok(detailSource.includes('Source SPX system zone interval'));
assert.ok(detailSource.includes('mapped zone'));
assert.ok(detailSource.includes('Mapped reference anchor (vs selected close)'));
console.log('SPX Map chart levels and observation-date SPXW pair OK');
