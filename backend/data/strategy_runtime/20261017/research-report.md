# SQL-backed US GEX research package — 2026-10-17

Research data cutoff: **2026-08-31**.
September and October 2026 are intentionally reserved for independent user validation.

Selected packets:

- ADBE: STRONG_VALIDATED, LONG D5, N=48, WR=79.2%, mean=3.46%
- GDX: STRONG_VALIDATED, LONG D5, N=30, WR=83.3%, mean=4.68%
- IWM: VALIDATED, LONG D5, N=33, WR=84.8%, mean=1.72%
- BABA: STRONG_VALIDATED, SHORT D5, N=33, WR=75.8%, mean=2.72%
- ORCL: PROMISING_SMALL_N, SHORT D3, N=23, WR=82.6%, mean=2.98%
- AAPL: VALIDATED, LONG D3, N=28, WR=67.9%, mean=0.94%
- DIA: STRONG_VALIDATED, LONG D5, N=23, WR=87.0%, mean=1.25%
- XLE: VALIDATED, LONG D5, N=41, WR=65.9%, mean=1.19%
- TXN: VALIDATED, SHORT D5, N=23, WR=73.9%, mean=2.95%
- WDC: PROMISING_SMALL_N, SHORT D5, N=15, WR=86.7%, mean=11.34%

Rejected candidate families remain in `research/candidate-summary.json` with their validation/final-tail outcomes. `StockData.OptionDelayedQuote_V2` was inspected but not required by the frozen production predicates. Its point-in-time convention is documented in each source manifest: ObservationDate is authoritative, CreateDate is ingestion-only, and open-interest availability follows the user-provided Sydney-time schedule.
