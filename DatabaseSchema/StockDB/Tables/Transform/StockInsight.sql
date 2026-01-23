-- Table: [Transform].[StockInsight]

CREATE TABLE [Transform].[StockInsight] (
    [ASXCode] [varchar](10) NOT NULL,
    [MC] [decimal](20,2) NULL,
    [TotalSharesIssued] [decimal](10,2) NULL,
    [FloatingShares] [decimal](20,2) NULL,
    [FloatingSharesPerc] [decimal](10,2) NULL,
    [CashPosition] [decimal](8,2) NULL,
    [RecentTopBuyBroker] [nvarchar](MAX) NULL,
    [RecentTopSellBroker] [nvarchar](MAX) NULL,
    [FriendlyNameList] [nvarchar](MAX) NULL,
    [MovingAverage5d] [decimal](20,4) NULL,
    [T1MovingAverage5d] [decimal](20,4) NULL,
    [MovingAverage10d] [decimal](20,4) NULL,
    [T1MovingAverage10d] [decimal](20,4) NULL,
    [MedianTradeValueWeekly] [int] NULL,
    [MedianTradeValueDaily] [int] NULL,
    [MedianPriceChangePerc] [decimal](10,2) NULL,
    [RelativePriceStrength] [decimal](10,2) NULL,
    [FurtherDetails] [varchar](2000) NULL,
    [IndustryGroup] [varchar](200) NULL,
    [IndustrySubGroup] [varchar](200) NULL,
    [MediumTermRetailParticipationRate] [decimal](10,2) NULL,
    [ShortTermRetailParticipationRate] [decimal](10,2) NULL,
    [LastValidateDate] [smalldatetime] NULL,
    [CreateDate] [smalldatetime] NULL
);
