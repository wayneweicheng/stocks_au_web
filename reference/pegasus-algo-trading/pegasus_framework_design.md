# Pegasus Framework Design (Draft)

This is a clean, minimal framework to support:
- Simple strategies like buy-at-support or buy-the-dip
- 5-minute bars from the DB table `StockData.PriceHistoryTimeFrame`
- Multiple concurrent orders per stock
- Bar-close stop loss
- Long and short entries via `Trading.Orders.Side` (`B`/`S`) (shorting gated by `ENABLE_SHORTING`)

## Rules Used

- Entry fill for LIMIT orders when `low <= entry_price <= high`, filled at `entry_price`.
- Profit target fill:
  - Long (`Side='B'`): when `high >= target`, filled at `target` price.
  - Short (`Side='S'`): when `low <= target`, filled at `target` price.
- Stop loss triggers only on bar close (`StopLossMode='BAR_CLOSE'`):
  - Long (`Side='B'`): when `bar.close <= stop_loss_price`, exit at bar close.
  - Short (`Side='S'`): when `bar.close >= stop_loss_price`, exit at bar close.

## Direction and Broker Actions

- `Side='B'`:
  - Entry is `BUY`.
  - Profit target / stop / exit is `SELL`.
- `Side='S'`:
  - Entry is `SELL` (short sell).
  - Profit target / stop / exit is `BUY` (buy-to-cover).
- `Quantity` is always positive; direction is encoded by `Side`.

## Feature Flags

- `ENABLE_SHORTING=false` (default): the engine will skip entering any order with `Side='S'` in both backtest and live mode.
- `SUPPORT_BOUNCE_ENABLE_SHORTS=true` enables short signal generation for the `support_bounce` strategy.

## Data Sources

- Historical bars: `[StockData].[PriceHistoryTimeFrame]` in `StockDB_US`
- TimeFrame for 5-minute bars: `TimeFrame = '5M'`
- Stock code includes country suffix, e.g. `QQQ.US`

## DB Schema

DDL and sample seed orders are in:
- `sql_scripts/pegasus_framework.sql`

## Framework Layout

- `common/models.py` contains Bar, Order, Fill.
- `common/bar_store.py` reads bars from DB.
- `common/order_store.py` reads orders and records fills.
- `common/engine.py` runs backtest logic.
- `common/strategy.py` defines the Strategy interface.
- `common/backtest_runner.py` provides a simple runner.
- `common/live_runner.py` handles live execution via IB.

## Intended Flow

1. Load bars from DB for a symbol and time window.
2. Load PENDING orders for that symbol.
3. Run bar-by-bar evaluation to enter/exit orders.
4. Emit fills for entry and exit.

## CLI Backtest

Run a DB-backed backtest:

```bash
python -m stocks_pegasus_algo_trade.common.cli_backtest \
  --stock QQQ.US \
  --start "2025-10-01 09:30:00" \
  --end "2025-10-01 16:00:00"
```
