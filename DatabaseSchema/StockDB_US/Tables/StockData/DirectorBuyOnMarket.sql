-- Table: [StockData].[DirectorBuyOnMarket]

CREATE TABLE [StockData].[DirectorBuyOnMarket] (
    [ASXCode] [varchar](10) NOT NULL,
    [CleansedMarketCap] [decimal](20,2) NULL,
    [ValueConsideration] [nvarchar](MAX) NULL,
    [ValueConsiderationPerShare] [nvarchar](MAX) NULL,
    [NumAcquired] [nvarchar](MAX) NULL,
    [NumDisposed] [nvarchar](MAX) NULL,
    [AnnDescr] [varchar](200) NOT NULL,
    [AnnDateTime] [smalldatetime] NOT NULL
);
