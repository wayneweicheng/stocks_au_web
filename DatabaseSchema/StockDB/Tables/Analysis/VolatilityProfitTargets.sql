-- Table: [Analysis].[VolatilityProfitTargets]

CREATE TABLE [Analysis].[VolatilityProfitTargets] (
    [ID] [int] IDENTITY(1,1) NOT NULL,
    [Stock] [varchar](20) NOT NULL,
    [TimeWindowStart] [time] NOT NULL,
    [TimeWindowEnd] [time] NOT NULL,
    [BarSizeMinutes] [int] NOT NULL DEFAULT ((5)),
    [AnalysisDate] [date] NOT NULL,
    [AnalysisPeriodDays] [int] NOT NULL DEFAULT ((30)),
    [SampleSize] [int] NOT NULL,
    [MedianMaxGainPct] [decimal](6,3) NULL,
    [Percentile60MaxGainPct] [decimal](6,3) NULL,
    [Percentile75MaxGainPct] [decimal](6,3) NULL,
    [StdDevMaxGainPct] [decimal](6,3) NULL,
    [DiscountMultiplier] [decimal](4,3) NOT NULL,
    [CalculatedTargetPct] [decimal](6,3) NULL,
    [FinalTargetPct] [decimal](6,3) NOT NULL,
    [MinCapApplied] [bit] NULL DEFAULT ((0)),
    [MaxCapApplied] [bit] NULL DEFAULT ((0)),
    [IsActive] [bit] NULL DEFAULT ((1)),
    [CreatedDate] [datetime] NULL DEFAULT (getdate()),
    [UpdatedDate] [datetime] NULL DEFAULT (getdate())
,
    CONSTRAINT [PK__Volatili__3214EC2773FF41C1] PRIMARY KEY (ID)
);

CREATE INDEX [IX_Stock_Lookup] ON [Analysis].[VolatilityProfitTargets] (Stock, TimeWindowStart, TimeWindowEnd, IsActive);
CREATE UNIQUE INDEX [UQ_Stock_TimeWindow_Active] ON [Analysis].[VolatilityProfitTargets] (Stock, TimeWindowStart, TimeWindowEnd, BarSizeMinutes, IsActive);