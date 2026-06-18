-- Table: [TA].[price_setup_state]

CREATE TABLE [TA].[price_setup_state] (
    [symbol] [varchar](32) NOT NULL,
    [as_of_date] [date] NOT NULL,
    [timeframe] [varchar](16) NOT NULL,
    [setup_state] [varchar](32) NOT NULL,
    [setup_score] [decimal](18,6) NULL,
    [issue_flags] [varchar](500) NULL,
    [preferred_pattern] [varchar](64) NULL,
    [preferred_pattern_score] [decimal](18,6) NULL,
    [breakout_level] [decimal](18,6) NULL,
    [stop_reference_level] [decimal](18,6) NULL,
    [created_at] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_price_setup_state] PRIMARY KEY (symbol, as_of_date, timeframe)
);
