-- Table: [TA].[price_pivot]

CREATE TABLE [TA].[price_pivot] (
    [symbol] [varchar](32) NOT NULL,
    [trade_date] [date] NOT NULL,
    [timeframe] [varchar](16) NOT NULL,
    [pivot_type] [varchar](16) NOT NULL,
    [pivot_price] [decimal](18,6) NOT NULL,
    [price_basis] [varchar](16) NOT NULL,
    [pivot_window] [int] NOT NULL,
    [significance_score] [decimal](18,6) NULL,
    [pivot_rank_recent] [int] NULL,
    [created_at] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_price_pivot] PRIMARY KEY (symbol, trade_date, timeframe, pivot_type, pivot_window)
);

CREATE INDEX [IX_price_pivot_symbol_timeframe_date] ON [TA].[price_pivot] (symbol, timeframe, trade_date);