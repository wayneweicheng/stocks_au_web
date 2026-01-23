-- Table: [Analysis].[VolatilityAnalysisConfig]

CREATE TABLE [Analysis].[VolatilityAnalysisConfig] (
    [ConfigID] [int] IDENTITY(1,1) NOT NULL,
    [Stock] [varchar](20) NOT NULL,
    [DiscountMultiplier] [decimal](4,3) NOT NULL,
    [MinProfitTargetPct] [decimal](6,3) NULL DEFAULT ((0.300)),
    [MaxProfitTargetPct] [decimal](6,3) NULL DEFAULT ((3.000)),
    [LookForwardBarsMin] [int] NULL DEFAULT ((6)),
    [LookForwardBarsMax] [int] NULL DEFAULT ((8)),
    [IsEnabled] [bit] NULL DEFAULT ((1)),
    [UpdatedDate] [datetime] NULL DEFAULT (getdate())
,
    CONSTRAINT [PK__Volatili__C3BC333CE7D9B240] PRIMARY KEY (ConfigID)
);

CREATE UNIQUE INDEX [UQ__Volatili__559FD85165AA4079] ON [Analysis].[VolatilityAnalysisConfig] (Stock);