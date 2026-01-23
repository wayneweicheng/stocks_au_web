-- Table: [Transform].[LeadingBreath]

CREATE TABLE [Transform].[LeadingBreath] (
    [ObservationDate] [date] NOT NULL,
    [TodayValueChange] [numeric](38,6) NULL,
    [TodayAverageChange] [decimal](10,2) NULL,
    [TodayChange] [decimal](10,2) NULL,
    [RowNumber] [bigint] NULL,
    [BreathClosePrice] [decimal](20,4) NULL,
    [SPXClosePrice] [decimal](20,4) NULL
);
