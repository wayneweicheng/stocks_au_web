-- Table: [StockData].[CompanyInfo]

CREATE TABLE [StockData].[CompanyInfo] (
    [CompanyInfoID] [bigint] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [StockCode] [nvarchar](10) NULL,
    [ScanDayTradeInfoUrl] [varchar](2000) NULL,
    [BusinessDetails] [varchar](2000) NULL,
    [SharesOnIssue] [bigint] NULL,
    [MarketCap] [bigint] NULL,
    [CleansedMarketCap] [decimal](20,2) NULL,
    [EPS] [decimal](10,4) NULL,
    [IndustryGroup] [varchar](200) NULL,
    [IndustrySubGroup] [varchar](200) NULL,
    [DateFrom] [smalldatetime] NULL,
    [DateTo] [smalldatetime] NULL,
    [LastValidateDate] [smalldatetime] NULL
);
