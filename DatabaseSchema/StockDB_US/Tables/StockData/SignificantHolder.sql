-- Table: [StockData].[SignificantHolder]

CREATE TABLE [StockData].[SignificantHolder] (
    [ASXCode] [varchar](10) NOT NULL,
    [CleansedMarketCap] [decimal](20,2) NULL,
    [AnnDescr] [varchar](200) NOT NULL,
    [AnnDateTime] [smalldatetime] NOT NULL
);
