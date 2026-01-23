-- Table: [StockData].[Stage2Stocks]

CREATE TABLE [StockData].[Stage2Stocks] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [Close] [decimal](20,4) NOT NULL,
    [MA50] [decimal](38,6) NULL,
    [MA150] [decimal](38,6) NULL,
    [MA200] [decimal](38,6) NULL,
    [Low52Weeks] [decimal](20,4) NULL,
    [High52Weeks] [decimal](20,4) NULL
);
