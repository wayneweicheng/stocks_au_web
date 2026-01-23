-- Table: [Transform].[StockPreMarketMatchVolume]

CREATE TABLE [Transform].[StockPreMarketMatchVolume] (
    [StockPreMarketMatchVolume] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [MatchVolumeOutOfFreeFloat] [decimal](20,2) NULL,
    [MatchVolume] [int] NULL,
    [FloatingShares] [decimal](20,2) NULL,
    [IndicativePrice] [decimal](20,4) NULL,
    [PrevClose] [decimal](20,4) NULL,
    [MatchValue] [int] NULL,
    [MatchPriceIncrease] [decimal](10,2) NULL,
    [OpenIncrease] [decimal](10,2) NULL,
    [CloseIncrease] [decimal](10,2) NULL,
    [HighIncrease] [decimal](10,2) NULL,
    [LowIncrease] [decimal](10,2) NULL
);
