-- Table: [Transform].[DailyInstituteBuySell]

CREATE TABLE [Transform].[DailyInstituteBuySell] (
    [ReportType] [varchar](29) NOT NULL,
    [DerivedInstitute] [bit] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NULL,
    [Quantity] [bigint] NULL,
    [InstituteTradeValue] [nvarchar](4000) NULL,
    [InstituteTradeValuePerc] [nvarchar](4000) NULL,
    [AvgTradeValuePerc] [decimal](10,2) NULL,
    [PriceChangeVsPrevClose] [decimal](20,4) NULL,
    [PriceChangeVsOpen] [decimal](10,2) NULL,
    [VWAPStrength] [int] NOT NULL,
    [InstituteBuyPerc] [numeric](38,6) NULL,
    [RetailBuyPerc] [numeric](38,6) NULL,
    [InstituteBuyVWAP] [decimal](38,6) NULL,
    [RetailBuyVWAP] [decimal](38,6) NULL,
    [RecentTopBuyBroker] [nvarchar](MAX) NULL,
    [RecentTopSellBroker] [nvarchar](MAX) NULL,
    [FriendlyNameList] [nvarchar](MAX) NULL
);
