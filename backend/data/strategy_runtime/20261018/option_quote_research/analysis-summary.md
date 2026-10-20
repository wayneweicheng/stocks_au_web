# OptionDelayedQuote_V2 and StockDB_US exploration

## Scope

A StockDB_US inventory was created covering **419 tables/views and 6,859 columns**:

- `../stockdb-us-table-inventory.csv`
- `../stockdb-us-research-map.md`

OptionDelayedQuote_V2 was then queried for all 58 August-universe candidate symbols through 2026-08-31. The quote snapshot uses `ObservationDate` as D0 and is assumed available before the next US session's 07:30 ET evaluation, per the operating convention supplied for this research.

## Quote coverage

- 58/58 symbols returned quote data.
- Coverage spans 2025-06-03 through 2026-08-31 overall.
- Median symbol history: 198 quote days.
- Short-history symbols include SPXU (47 days), ZS/S/IGV/COHR/MOD (about 68–69 days).
- The short-history symbols are retained and reported; they are not silently discarded.

## Features tested

Daily causal aggregates were built from `StockData.OptionDelayedQuote_V2`:

- total/call/put option volume;
- total/call/put open interest;
- volume/open-interest ratio;
- put/call volume and OI ratios;
- volume-weighted implied volatility;
- call-versus-put IV difference;
- near-term (0–45 DTE) volume and concentration;
- volume-weighted bid/ask spread;
- volume-weighted absolute delta, gamma, and vega exposure;
- contract counts;
- prior-60-observation ranks and absolute-change ranks.

The current-row quote is used only as a D0 feature. Rank distributions exclude D0 and require at least ten prior observations. No September/October data was used to select a rule.

## Chronological screen results

The option screens were applied after each existing selected GEX trigger and evaluated with a 60/20/20 chronological split. Only eight variants passed positive train/validation checks with at least six training and three validation observations:

| Ticker | Exit | Screen | Train PF | Validation PF | Final-tail PF | Final N |
|---|---|---|---:|---:|---:|---:|
| AMAT | D5 | IV high | 9.67 | 3.10 | 1.71 | 2 |
| COPX | D1 | OI high | 1.99 | 2.00 | 0.00 | 3 |
| IBIT | D3 | IV low | 2.41 | 2.80 | 0.00 | 2 |
| META | D1 | IV high | 4.15 | 10.18 | 1.09 | 5 |
| MU | D5 | OI high | 4.88 | 3.21 | unavailable | 0 |
| TLT | D1 | OI high | 1.18 | 5.47 | 1.33 | 5 |

The final research tails are too small for promotion. The result is nevertheless useful: option IV/OI features have enough coverage and causal timing to justify continued research, especially for volatility-sensitive technology names.

## Decision

OptionDelayedQuote_V2 should be included in the next research generation. It should not yet be inserted into the current live packet predicates because the current sample has very small final tails and many variants were tested.

Next tests should include:

1. option screens with fixed and continuous strength rather than only 0.20/0.80 ranks;
2. IV and bandwidth interaction for META/MRVL/AMD/MU;
3. OI/volume changes and call/put asymmetry;
4. spread/liquidity costs and minimum quote quality;
5. D5 volatility-scaled exits and 30-minute MAE paths;
6. pooled cross-sectional models with ticker-held-out validation to reduce per-ticker small-sample bias.

Artifacts:

- `option-quote-daily-features.csv`
- `option-screen-results.csv`
- `option-screen-walkforward-results.csv`
- `option-screen-walkforward-selected.csv`
- `run-metadata.json`
