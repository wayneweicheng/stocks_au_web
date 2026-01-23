-- Table: [StockData].[IndicativePrice]

CREATE TABLE [StockData].[IndicativePrice] (
    [IndicativePriceID] [int] IDENTITY(1,1) NOT NULL,
    [SaleDateTime] [datetime] NOT NULL,
    [Price] [decimal](20,4) NOT NULL,
    [Quantity] [bigint] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [CreateDate] [datetime] NOT NULL,
    [ActBuySellInd] [char](1) NULL
,
    CONSTRAINT [pk_stockdataindicativeprice_indicativepriceid] PRIMARY KEY (IndicativePriceID)
);
