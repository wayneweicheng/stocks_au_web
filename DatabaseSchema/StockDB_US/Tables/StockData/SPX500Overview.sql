-- Table: [StockData].[SPX500Overview]

CREATE TABLE [StockData].[SPX500Overview] (
    [ObservationDate] [date] NOT NULL,
    [PercentageAboveSMA50] [decimal](5,2) NULL,
    [PercentageAboveSMA200] [decimal](5,2) NULL
);
