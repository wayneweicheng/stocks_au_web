-- Table: [TA].[price_trendline]

CREATE TABLE [TA].[price_trendline] (
    [symbol] [varchar](32) NOT NULL,
    [as_of_date] [date] NOT NULL,
    [timeframe] [varchar](16) NOT NULL,
    [line_family] [varchar](16) NOT NULL,
    [line_type] [varchar](32) NOT NULL,
    [start_date] [date] NULL,
    [end_date] [date] NULL,
    [slope] [decimal](18,10) NOT NULL,
    [intercept] [decimal](18,10) NULL,
    [normalized_slope] [decimal](18,10) NULL,
    [touch_count] [int] NULL,
    [avg_distance_pct] [decimal](18,6) NULL,
    [max_violation_pct] [decimal](18,6) NULL,
    [respect_score] [decimal](18,6) NULL,
    [r_squared] [decimal](18,6) NULL,
    [created_at] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_price_trendline] PRIMARY KEY (symbol, as_of_date, timeframe, line_family, line_type)
);

CREATE INDEX [IX_price_trendline_symbol_as_of] ON [TA].[price_trendline] (symbol, as_of_date, timeframe, line_family);