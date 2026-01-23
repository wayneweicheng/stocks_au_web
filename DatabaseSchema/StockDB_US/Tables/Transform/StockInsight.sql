-- Table: [Transform].[StockInsight]

CREATE TABLE [Transform].[StockInsight] (
    [ASXCode] [varchar](10) NOT NULL,
    [MC] [decimal](8,2) NULL,
    [FloatingShares] [decimal](20,2) NULL,
    [FloatingSharesPerc] [decimal](10,2) NULL,
    [CashPosition] [decimal](8,2) NULL,
    [MedianTradeValueWeekly] [int] NULL,
    [MedianTradeValueDaily] [int] NULL,
    [MedianPriceChangePerc] [decimal](10,2) NULL,
    [RelativePriceStrength] [decimal](10,2) NULL,
    [Value in K] [decimal](10,2) NULL,
    [ChangePerc] [decimal](10,2) NULL,
    [ValueOverMC] [decimal](5,2) NULL,
    [FurtherDetails] [varchar](2000) NULL,
    [EPS] [decimal](10,4) NULL,
    [IndustryGroup] [varchar](200) NULL,
    [IndustrySubGroup] [varchar](200) NULL,
    [MediumTermRetailParticipationRate] [decimal](10,2) NULL,
    [ShortTermRetailParticipationRate] [decimal](10,2) NULL,
    [LastValidateDate] [smalldatetime] NULL,
    [Poster] [nvarchar](MAX) NULL,
    [CreateDate] [smalldatetime] NULL
);
