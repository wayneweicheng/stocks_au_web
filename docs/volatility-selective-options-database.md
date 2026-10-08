# Volatility-Selective Options database setup

The non-executing implementation requires SQL Server audit tables. No broker
order table is created or modified by this feature.

Execute these checked-in scripts against **StockDB_US** in this order:

1. `DatabaseSchema/StockDB_US/Tables/Analysis/VolatilitySelectiveOptions.sql`
2. `DatabaseSchema/StockDB_US/Tables/Analysis/VolatilitySelectiveEvent.sql`
3. `DatabaseSchema/StockDB_US/Tables/Analysis/VolatilitySelectiveSafetyState.sql`
4. `DatabaseSchema/StockDB_US/Tables/Analysis/VolatilitySelectiveBacktestDataset.sql`
5. `DatabaseSchema/StockDB_US/Indexes/Analysis/VolatilitySelectiveOptions.sql`

The scripts are idempotent for existing tables/indexes.

## Reference data you need to provide

Before enabling scheduled scans:

- `Configuration.VolatilitySelectiveSchedule`: one `default` row can be
  created by the web page. Set `Enabled = 0` until the system has been
  validated.
- `Analysis.VolatilitySelectiveEvent`: populate known stock earnings,
  dividends, corporate actions, and other binary event windows. A stock with no
  verified event state fails closed unless its symbol is explicitly included
  in the schedule's `EventClearSymbols` list.
- Account equity and existing assignment exposure must be entered by the
  operator. The system does not infer a safe personal risk budget from IB
  buying power.

Example event reference row:

```sql
INSERT INTO [Analysis].[VolatilitySelectiveEvent]
    (Symbol, EventType, EventDate, Status, Source, Notes)
VALUES
    ('NVDA', 'EARNINGS', '2026-11-18', 'CONFIRMED', 'operator-calendar-review', 'Verify before enabling scan');
```

Do not insert fake historical option data. Backtesting requires a separate
point-in-time dataset with historical bid/ask/IV/Greeks and forward outcomes;
see `midas-touch/volatility-selective-options/references/historical-dataset.md`.

## Operational safety

- Scheduled scans generate reports, persist candidates, and send idempotent
  alerts only.
- The manual safety kill switch stops scheduled scans. It is an operational
  research safeguard; it is not a broker order-control mechanism because this
  application has no automated broker execution.
- Manual positions are records of trades the operator entered outside this
  application.
- Monitor recommendations are informational. The application has no IBKR
  order submission, cancellation, repricing, or automated exit path.
- Pushover credentials continue to come from the existing backend environment;
  they are not stored in SQL Server or committed to the repository.
