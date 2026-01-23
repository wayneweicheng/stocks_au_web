-- Table: [StockData].[WeeklyMonthlyPriceAction]

CREATE TABLE [StockData].[WeeklyMonthlyPriceAction] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [FirstDateofMonth] [date] NULL,
    [LastDateofMonth] [date] NULL,
    [FirstDateofWeek] [date] NULL,
    [LastDateofWeek] [date] NULL,
    [Close] [decimal](20,4) NOT NULL,
    [MonthlyMovingAverage5d] [decimal](20,4) NULL,
    [MonthlyMovingAverage10d] [decimal](20,4) NULL,
    [MonthlyPrev1MovingAverage5d] [decimal](20,4) NULL,
    [MonthlyPrev2MovingAverage5d] [decimal](20,4) NULL,
    [WeeklyMovingAverage5d] [decimal](20,4) NULL,
    [WeeklyMovingAverage10d] [decimal](20,4) NULL,
    [WeeklyPrev1MovingAverage5d] [decimal](20,4) NULL,
    [WeeklyPrev1MovingAverage10d] [decimal](20,4) NULL,
    [MedianTradeValueWeekly] [int] NULL,
    [MedianTradeValueDaily] [int] NULL,
    [MedianPriceChangePerc] [decimal](10,2) NULL,
    [ActionType] [varchar](100) NOT NULL,
    [CreateDate] [smalldatetime] NULL
);
