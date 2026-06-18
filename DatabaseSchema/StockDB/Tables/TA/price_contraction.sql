-- Table: [TA].[price_contraction]

CREATE TABLE [TA].[price_contraction] (
    [symbol] [varchar](32) NOT NULL,
    [as_of_date] [date] NOT NULL,
    [timeframe] [varchar](16) NOT NULL,
    [contraction_count] [int] NULL,
    [pullback_1_pct] [decimal](18,6) NULL,
    [pullback_2_pct] [decimal](18,6) NULL,
    [pullback_3_pct] [decimal](18,6) NULL,
    [pullback_4_pct] [decimal](18,6) NULL,
    [contraction_ratio_1_2] [decimal](18,6) NULL,
    [contraction_ratio_2_3] [decimal](18,6) NULL,
    [contraction_ratio_3_4] [decimal](18,6) NULL,
    [atr_contraction_ratio] [decimal](18,6) NULL,
    [range_contraction_ratio] [decimal](18,6) NULL,
    [volume_dry_up_score] [decimal](18,6) NULL,
    [pivot_tightness_score] [decimal](18,6) NULL,
    [contraction_sequence_valid] [bit] NULL,
    [notes] [varchar](500) NULL,
    [created_at] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_price_contraction] PRIMARY KEY (symbol, as_of_date, timeframe)
);
