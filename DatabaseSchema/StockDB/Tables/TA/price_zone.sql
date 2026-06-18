-- Table: [TA].[price_zone]

CREATE TABLE [TA].[price_zone] (
    [symbol] [varchar](32) NOT NULL,
    [as_of_date] [date] NOT NULL,
    [timeframe] [varchar](16) NOT NULL,
    [zone_type] [varchar](16) NOT NULL,
    [lower_bound] [decimal](18,6) NOT NULL,
    [upper_bound] [decimal](18,6) NOT NULL,
    [center_price] [decimal](18,6) NOT NULL,
    [touch_count] [int] NOT NULL,
    [first_touch_date] [date] NULL,
    [last_touch_date] [date] NULL,
    [zone_strength_score] [decimal](18,6) NULL,
    [created_at] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_price_zone] PRIMARY KEY (symbol, as_of_date, timeframe, zone_type, center_price)
);

CREATE INDEX [IX_price_zone_symbol_as_of] ON [TA].[price_zone] (symbol, as_of_date, timeframe, zone_type);