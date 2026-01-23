-- Table: [StockAI].[BRWeeklyInvesthStrategy]

CREATE TABLE [StockAI].[BRWeeklyInvesthStrategy] (
    [ASXCode] [varchar](10) NOT NULL,
    [StartDate] [date] NULL,
    [EndDate] [date] NULL,
    [Buyer] [nvarchar](100) NOT NULL,
    [BuyVolume] [bigint] NULL,
    [SellVolume] [bigint] NULL,
    [NetVolume] [bigint] NULL,
    [BuyValue] [decimal](38,2) NULL,
    [SellValue] [decimal](38,2) NULL,
    [NetValue] [decimal](38,2) NULL,
    [BuyVWAP] [numeric](38,6) NULL,
    [SellVWAP] [numeric](38,6) NULL,
    [SelfTradeVolume] [bigint] NULL,
    [SelfTradePerc] [numeric](38,17) NULL,
    [RowNumber] [bigint] NULL,
    [TodayChange] [decimal](10,2) NULL,
    [TomorrowChange] [decimal](10,2) NULL,
    [Next2DaysChange] [decimal](10,2) NULL,
    [Next5DaysChange] [decimal](10,2) NULL,
    [Next10DaysChange] [decimal](10,2) NULL,
    [Prev2DaysChange] [decimal](10,2) NULL,
    [Prev10DaysChange] [decimal](10,2) NULL
);
