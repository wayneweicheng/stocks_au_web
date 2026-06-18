-- Table: [TA].[price_daily]

CREATE TABLE [TA].[price_daily] (
    [symbol] [varchar](32) NOT NULL,
    [trade_date] [date] NOT NULL,
    [open_price] [decimal](18,6) NOT NULL,
    [high_price] [decimal](18,6) NOT NULL,
    [low_price] [decimal](18,6) NOT NULL,
    [close_price] [decimal](18,6) NOT NULL,
    [volume] [bigint] NOT NULL,
    [adjusted_close] [decimal](18,6) NULL,
    [created_at] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_price_daily] PRIMARY KEY (symbol, trade_date)
);

CREATE INDEX [IX_price_daily_trade_date] ON [TA].[price_daily] (trade_date, symbol);