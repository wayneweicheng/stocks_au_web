-- Table: [Transform].[PriceSummaryLatestFutureMA]

CREATE TABLE [Transform].[PriceSummaryLatestFutureMA] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NULL,
    [Close] [decimal](20,4) NOT NULL,
    [Volume] [bigint] NOT NULL,
    [MovingAverage5d] [decimal](38,6) NULL,
    [MovingAverage10d] [decimal](38,6) NULL,
    [MovingAverage20d] [decimal](38,6) NULL,
    [MovingAverage30d] [decimal](38,6) NULL,
    [MovingAverage50d] [decimal](38,6) NULL,
    [MovingAverage60d] [decimal](38,6) NULL,
    [MovingAverage100d] [decimal](38,6) NULL,
    [MovingAverage50dVol] [bigint] NULL,
    [RowNumber] [bigint] NULL
);
