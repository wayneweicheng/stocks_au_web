-- Table: [StockData].[PriceHistory5M]

CREATE TABLE [StockData].[PriceHistory5M] (
    [ASXCode] [varchar](10) NULL,
    [TimeIntervalStart] [smalldatetime] NULL,
    [Open] [decimal](20,4) NULL,
    [High] [decimal](20,4) NULL,
    [Low] [decimal](20,4) NULL,
    [Close] [decimal](20,4) NULL,
    [Volume] [bigint] NOT NULL,
    [FirstSale] [datetime] NULL,
    [LastSale] [datetime] NULL,
    [SaleValue] [decimal](38,4) NOT NULL,
    [NumOfSale] [int] NOT NULL,
    [AverageValuePerTransaction] [decimal](38,6) NULL,
    [VWAP] [decimal](38,6) NULL,
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL
,
    CONSTRAINT [pk_transform_pricehistory5m_uniquekey] PRIMARY KEY (UniqueKey)
);
