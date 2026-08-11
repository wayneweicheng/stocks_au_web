# SPXW GEX signal assistant

The implementation lives under `backend/app/spx_gex_strategy`.

## Production data sources

Live runs read the raw rows with the equivalent of:

```sql
SELECT TOP (100000) *
FROM [StockDB_US].[Transform].[OptionGEXChangeCapitalType] WITH (NOLOCK)
WHERE ASXCode = ? -- SPXW.US
  AND ObservationDate >= CONVERT(date, ?)
  AND ObservationDate < DATEADD(day, 1, CONVERT(date, ?))
  AND CapitalType IN ('BC', 'BP', 'SC', 'SP')
ORDER BY ObservationDate ASC, CapitalType ASC;
```

The code validates exactly one `BC`, `BP`, `SC`, and `SP` row per date before calculating the causal rolling thresholds. The supplied SPXW summary CSV remains available with `SPX_GEX_DATA_MODE=file` for offline checks/backtests.

`NQMAIN` is a database name, not an IB contract. The live quote adapter follows the existing futures collector and qualifies:

```python
ContFuture(symbol="NQ", exchange="CME", currency="USD")
```

It reads the current market/delayed quote and compares it with the latest completed IB daily `TRADES` bar before today. The report shows both prices and the percentage move. The 30-minute historical source remains `NQMAIN.US` and is labeled `NQ_PROXY` for shadow trades.

## New York schedule

APScheduler uses `America/New_York`, not a fixed UTC offset:

- 03:25: source-data availability check
- 03:29: daily signal classification, conflict check, and Pushover notification for the 03:30 action boundary
- 03:31: one New York-time retry if the table refresh completed just after 03:29; signal/notification writes are idempotent
- Every 30 minutes from 03:00 through 16:30: pending dip/entry/exit shadow monitor
- 16:05 on the final US cash session of each month: monthly report and forward-test milestones

This stays at 03:29/03:30 New York across EDT/EST. Sydney time is not used for scheduling.

## Pushover and report link

Set these in `backend/.env` (never commit them):

```env
PUSHOVER_USER_KEY=your-user-key
PUSHOVER_APP_TOKEN=your-application-token
PUSHOVER_DEVICE=droid4
PUSHOVER_SOUND=echo
SPX_GEX_REPORT_URL=https://your-host.example.com/api/spx-gex/report.html
SPX_GEX_REPORT_TOKEN=optional-shared-read-only-token
```

The notification uses Pushover's native `url`/`url_title` fields and includes the same URL in the message body. The existing collector helper uses the same Pushover endpoint, but this service does not copy its embedded credentials; secrets stay in environment configuration as required by the PRD.

## Manual commands

From `backend` with the project virtual environment active:

```bash
python -m app.spx_gex_strategy daily
python -m app.spx_gex_strategy monitor
python -m app.spx_gex_strategy live-nq
python -m app.spx_gex_strategy report
python -m app.spx_gex_strategy backtest --start 2025-03-01 --end 2026-08-06 --initial-capital 100000 --exposure 1.0
python -m app.spx_gex_strategy trade confirm <trade_id>
python -m app.spx_gex_strategy trade skip <trade_id>
python -m app.spx_gex_strategy trade close <trade_id> --price 123.45
```

The read-only latest HTML report is available at `/api/spx-gex/report.html`; if a report token is configured, the configured Pushover URL includes it automatically. Each successful daily signal run also stores an immutable HTML snapshot in the strategy database. The archive is available at `/api/spx-gex/reports`, and a dated snapshot at `/api/spx-gex/reports/YYYY-MM-DD.html`. Re-running a date never overwrites an existing snapshot: identical content is idempotent, while changed content receives a separate report ID.

## Explicit PRD assumption

The PRD specifies Yellow TP/SL first-touch behavior but does not specify a Yellow time-exit boundary. The implementation therefore does not invent one: a Yellow shadow position remains active until TP or SL is observed. Green positions use the explicitly specified D5 cash-close exit. This should be resolved and versioned before relying on a historical Yellow equity curve.
