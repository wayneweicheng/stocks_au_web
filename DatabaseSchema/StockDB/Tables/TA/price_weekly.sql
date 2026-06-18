-- Table: [TA].[price_weekly]

CREATE TABLE [TA].[price_weekly] (
    [symbol] [varchar](32) NOT NULL,
    [week_end_date] [date] NOT NULL,
    [open_price] [decimal](18,6) NOT NULL,
    [high_price] [decimal](18,6) NOT NULL,
    [low_price] [decimal](18,6) NOT NULL,
    [close_price] [decimal](18,6) NOT NULL,
    [volume] [bigint] NOT NULL,
    [source_start_date] [date] NOT NULL,
    [source_end_date] [date] NOT NULL,
    [created_at] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_price_weekly] PRIMARY KEY (symbol, week_end_date)
);
