-- Table: [StockData].[ShareHolderStockPriceChange]

CREATE TABLE [StockData].[ShareHolderStockPriceChange] (
    [StockPriceChangeID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ShareHolder] [varchar](500) NOT NULL,
    [StartObservationDate] [date] NOT NULL,
    [EndObservationDate] [date] NOT NULL,
    [EndClose] [decimal](20,4) NOT NULL,
    [StartClose] [decimal](20,4) NOT NULL,
    [PriceIncrease%] [decimal](10,2) NULL,
    [EndWeekTradeValue(M)] [decimal](10,2) NULL,
    [MC] [numeric](23,5) NULL,
    [CashPosition] [numeric](26,6) NULL,
    [Nature] [nvarchar](MAX) NULL,
    [Poster] [nvarchar](MAX) NULL,
    [CurrDate] [date] NULL,
    [DaysGoBack] [int] NULL,
    [StockType] [varchar](50) NULL
,
    CONSTRAINT [pk_stockdata_shareholderrating_stockpricechangeid] PRIMARY KEY (StockPriceChangeID)
);
