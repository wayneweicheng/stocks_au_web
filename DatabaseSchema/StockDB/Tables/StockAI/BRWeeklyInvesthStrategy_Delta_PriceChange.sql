-- Table: [StockAI].[BRWeeklyInvesthStrategy_Delta_PriceChange]

CREATE TABLE [StockAI].[BRWeeklyInvesthStrategy_Delta_PriceChange] (
    [Buyer] [nvarchar](100) NOT NULL,
    [StartDate] [date] NULL,
    [EndDate] [date] NULL,
    [PrevStartDate] [date] NULL,
    [PrevEndDate] [date] NULL,
    [ChangeType] [nvarchar](7) NOT NULL,
    [ASXCode] [varchar](10) NULL,
    [CurrentRank] [bigint] NULL,
    [PrevRank] [bigint] NULL,
    [CurrentNetVolume] [bigint] NULL,
    [PrevNetVolume] [bigint] NULL,
    [CurrentNetValue] [decimal](38,2) NULL,
    [PrevNetValue] [decimal](38,2) NULL,
    [ObservationDate] [date] NULL,
    [TodayChange] [decimal](10,2) NULL,
    [Next2DaysChange] [decimal](10,2) NULL,
    [Next5DaysChange] [decimal](10,2) NULL,
    [Next10DaysChange] [decimal](10,2) NULL
);
