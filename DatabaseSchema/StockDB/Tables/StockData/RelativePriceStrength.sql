-- Table: [StockData].[RelativePriceStrength]

CREATE TABLE [StockData].[RelativePriceStrength] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [PriceChange] [decimal](8,2) NULL,
    [PriceChangeRank] [bigint] NULL,
    [RelativePriceStrength] [numeric](38,12) NULL,
    [DateSeq] [int] NULL,
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL
,
    CONSTRAINT [pk_stockdata_relativepricestrength_uniquekey] PRIMARY KEY (UniqueKey)
);
