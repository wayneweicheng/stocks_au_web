# IB Framework Overview (IB insync + Common)

This document summarizes how the existing IB trading framework is wired, using the reference strategy `Ref/QQQStrategy_BuyDip/Strategy-QQQ-BuyDip-US.py` and the shared modules in `Common/`.

**Scope**
- Focus is on understanding the current architecture and how to use it consistently.
- It does not attempt to refactor or simplify the framework yet.

**Entry Points**
- Reference strategies are executable scripts under `Ref/`.
- Each strategy typically:
  - Loads `.env` from its own folder.
  - Builds `IBTrader`, `StrategyHelper`, and a strategy subclass of `StrategyBaseLongTrade`.
  - Chooses backtest or live mode via environment flags.
  - Calls `process_backtest_strategy()` or `process_live_strategy()`.

**Core Data Flow**
- Orders are pulled from database views and stored procedures.
- Each order becomes a `StrategyOrder` instance (contains state, params, and runtime tracking).
- `IBTrader` manages IB connections, subscriptions, and order placement using `ib_insync`.
- `StrategyHelper` maintains `StockBars` for each symbol, which converts IB bar lists into pandas DataFrames and computes indicators.
- The strategy subclass defines `meet_buy_condition()` and `meet_sell_condition()` to decide entries and exits.
- Order status updates from IB are routed back to the correct `StrategyOrder` via IB order ids.

**Common Modules and Roles**
- `Common/TradeHelper/IBTrader.py`
  - Wraps `ib_insync.IB` to handle connection, historical data subscriptions, ticker updates, and order placement.
  - Tracks mapping from IB OrderId to Strategy OrderID for multi-order support.
- `Common/TradeHelper/StrategyBaseLongTrade.py`
  - Base class for long strategies.
  - Loads orders from DB, creates `StrategyOrder` objects, and maintains `stock_list`.
  - Schedules refresh loops in live mode and simulates time windows in backtest mode.
  - Provides order lifecycle callbacks (`onOrderStatus`, `onExecDetails`) used for fills and sell logic.
- `Common/TradeHelper/StrategyHelper.py`
  - Maintains a list of `StockBars` objects keyed by symbol.
  - Requests historical data for symbols and converts raw IB bars into `StockBars`.
- `Common/TradeHelper/StockBars.py`
  - Converts `ib_insync` bar data to pandas DataFrame.
  - Converts time to US/Eastern for US stocks.
  - Calculates indicators like SMA, RSI, ATR, Bollinger Bands, peaks/troughs, and VWAP.
  - Exposes `key_price` and the processed DataFrame.
- `Common/TradeHelper/StrategyOrder.py`
  - Holds per-order configuration and runtime state.
  - Manages bar completion logic and profit targets.
  - Stores `entry_extra`, `exit_extra`, and `other_extra` to pass strategy-specific metadata.
- `Common/SQLServerHelper/SQLServerHelper.py`
  - Simple ODBC wrapper used for stored procedures and queries.
- `Common/LogHelper/LogHelper.py`
  - Sets up daily rolling log files for strategies.

**QQQ Buy Dip Strategy: How It Uses the Framework**
- File: `Ref/QQQStrategy_BuyDip/Strategy-QQQ-BuyDip-US.py`.
- Initializes logging and IB connection.
- Reads configuration from local `.env` in the same folder.
- Extends `StrategyBaseLongTrade` as `BuyTheDip`.
- Overrides `refresh_stock_list()` to read `AS_BuyConditionType` from DB and load extra config for `DROP_WINDOW_REVERSAL`.
- Uses `StockBars` to detect:
  - Dragonfly doji reversal.
  - SMA(10) upturn.
  - Drop-window reversal (DB-configured thresholds and time window).
- Entry conditions are selected by `AS_BuyConditionType` and stored in `StrategyOrder.other_extra`.
- Sell logic uses a bar-by-bar reversal rule after the buy fill.

**Database Expectations**
- Orders are loaded from stored procedures and a view that exposes JSON fields.
- `Order.v_Order` must expose `AS_BuyConditionType` from `AdditionalSettings`.
- For `DROP_WINDOW_REVERSAL`, `Strategy.PriceDropWindowConfig_US` provides thresholds and windows per stock.

**Backtest vs Live Mode**
- Backtest mode:
  - Pulls orders from `BackTest.usp_GetOrder`.
  - Iterates time in bar-size increments and calls `bar_update_event`.
  - Can serialize historical bars for reproducibility.
- Live mode:
  - Schedules `refresh_stock_list()` every 30 seconds.
  - Subscribes to historical bar updates and processes live bar updates.
  - Hooks IB order status events for fills and exits.

**Notes for Consistent Use**
- Ensure `.env` exists alongside the strategy script with IB host, port, client id, and strategy flags.
- Database views must expose JSON fields expected by the strategy.
- `MULTI_ORDER_ALLOWED_TYPES` controls whether multiple orders per stock are allowed (important for OrderType 29).
- `BarCompletedInMin` in `AdditionalSettings` drives the bar size used in signals.

**Known Complexity Hotspots**
- Many responsibilities are mixed in `StrategyBaseLongTrade` (data refresh, scheduling, order lifecycle).
- `StrategyOrder` is both config and runtime state.
- Time handling is spread across `StockBars`, `StrategyBaseLongTrade`, and strategy code.
