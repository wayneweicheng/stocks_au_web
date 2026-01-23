-- Table: [Transform].[MatchVolumeOutOfFreeFloatHistory]

CREATE TABLE [Transform].[MatchVolumeOutOfFreeFloatHistory] (
    [AvgVolume] [bigint] NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDateTime] [datetime] NOT NULL,
    [Grade] [numeric](3,1) NULL,
    [AnnDateTime] [smalldatetime] NULL,
    [IndicativePrice] [decimal](20,4) NULL,
    [PriceChange] [decimal](10,2) NULL,
    [PrevClose] [decimal](20,4) NULL,
    [MatchVolume] [int] NULL,
    [IndicativeMatchValue] [decimal](20,2) NULL,
    [MatchVolumeOutOfFreeFloat] [decimal](20,2) NULL,
    [DailyChangeRate] [decimal](20,2) NULL,
    [Last5PriceChange] [nvarchar](MAX) NULL,
    [SumPriceChangeVsPrevClose] [decimal](38,2) NULL,
    [MaxPriceIncrease] [decimal](20,2) NULL,
    [AnnDescr] [varchar](200) NULL,
    [FriendlyNameList] [nvarchar](MAX) NULL,
    [MarketCap] [decimal](20,2) NULL,
    [MedianTradeValueWeekly] [int] NULL,
    [MedianTradeValueDaily] [int] NULL,
    [MedianPriceChangePerc] [decimal](10,2) NULL,
    [RelativePriceStrength] [decimal](10,2) NULL,
    [ShortTermRetailParticipationRate] [decimal](10,2) NULL,
    [MediumTermRetailParticipationRate] [decimal](10,2) NULL
);
