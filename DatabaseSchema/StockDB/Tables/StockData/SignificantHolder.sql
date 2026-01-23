-- Table: [StockData].[SignificantHolder]

CREATE TABLE [StockData].[SignificantHolder] (
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [CleansedMarketCap] [decimal](20,2) NULL,
    [AnnDescr] [varchar](200) NOT NULL,
    [AnnDateTime] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_stockdata_significantholder_uniquekey] PRIMARY KEY (UniqueKey)
);
