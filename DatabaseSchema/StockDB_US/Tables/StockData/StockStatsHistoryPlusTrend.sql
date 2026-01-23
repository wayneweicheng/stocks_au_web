-- Table: [StockData].[StockStatsHistoryPlusTrend]

CREATE TABLE [StockData].[StockStatsHistoryPlusTrend] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [Close] [decimal](20,4) NOT NULL,
    [MovingAverage10d] [decimal](20,4) NULL,
    [PrevMovingAverage10d] [decimal](20,4) NULL,
    [MovingAverage20d] [decimal](20,4) NULL,
    [PrevMovingAverage20d] [decimal](20,4) NULL,
    [MovingAverage60d] [decimal](20,4) NULL,
    [PrevMovingAverage60d] [decimal](20,4) NULL
);
