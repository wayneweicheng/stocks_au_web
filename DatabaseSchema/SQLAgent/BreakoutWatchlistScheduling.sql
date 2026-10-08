-- SQL Agent scheduling for the ASX breakout watchlist.
-- Run in msdb after deploying the StockDB stored procedures.
--
-- The high-frequency writer must stop before the daily ASX loader starts;
-- both write StockData.PriceHistory, whose key does not include Exchange.
-- The breakout calculation must run after the 23:45 price-history refresh.

USE [msdb];
GO

-- High Frequency Refresh: stop at 16:29:59, before the 16:30 daily run.
EXEC dbo.sp_update_schedule
    @schedule_id = 15,
    @active_end_time = 162959;
GO

-- Breakout refresh: one weekday run at 00:15, after the 23:45 refresh
-- has had time to complete. The stored procedure selects the latest
-- sufficiently populated transformed date, so the midnight date rollover
-- is intentional.
EXEC dbo.sp_update_schedule
    @schedule_id = 1065,
    @freq_subday_type = 1,
    @freq_subday_interval = 0,
    @active_start_time = 1500,
    @active_end_time = 1500;
GO
