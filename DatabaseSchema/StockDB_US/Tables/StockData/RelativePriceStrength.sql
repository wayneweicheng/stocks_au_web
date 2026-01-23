-- Table: [StockData].[RelativePriceStrength]

CREATE TABLE [StockData].[RelativePriceStrength] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [PriceChange] [decimal](20,2) NULL,
    [PriceChangeRank] [bigint] NULL,
    [RelativePriceStrength] [numeric](38,12) NULL,
    [DateSeq] [int] NULL
);
