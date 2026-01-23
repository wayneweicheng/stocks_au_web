-- Table: [Working].[TokenPriceVolumeHistory]

CREATE TABLE [Working].[TokenPriceVolumeHistory] (
    [Token] [varchar](200) NULL,
    [ObservationDate] [varchar](50) NULL,
    [TradeValue] [decimal](38,4) NULL,
    [ASXCode] [int] NULL,
    [SMA0] [decimal](38,5) NULL,
    [SMA3] [decimal](38,5) NULL,
    [SMA5] [decimal](38,5) NULL,
    [SMA10] [decimal](38,5) NULL,
    [SMA20] [decimal](38,5) NULL,
    [SMA30] [decimal](38,5) NULL
);
