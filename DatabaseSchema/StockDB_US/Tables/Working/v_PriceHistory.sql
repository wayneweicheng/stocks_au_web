-- Table: [Working].[v_PriceHistory]

CREATE TABLE [Working].[v_PriceHistory] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [Close] [decimal](20,4) NOT NULL,
    [Open] [decimal](20,4) NOT NULL,
    [Low] [decimal](20,4) NOT NULL,
    [High] [decimal](20,4) NOT NULL,
    [Volume] [bigint] NOT NULL,
    [Value] [decimal](20,4) NULL,
    [Trades] [int] NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [ModifyDate] [smalldatetime] NULL,
    [VWAP] [decimal](20,4) NULL,
    [PrevClose] [decimal](20,4) NULL,
    [NextOpen] [decimal](20,4) NULL,
    [NextClose] [decimal](20,4) NULL,
    [Next2Close] [decimal](20,4) NULL,
    [Next5Close] [decimal](20,4) NULL,
    [TodayChange] [decimal](10,2) NULL,
    [TomorrowChange] [decimal](10,2) NULL,
    [Next2DaysChange] [decimal](10,2) NULL,
    [Next5DaysChange] [decimal](10,2) NULL,
    [TodayOpenToCloseChange] [decimal](10,2) NULL,
    [TomorrowOpenToCloseChange] [decimal](10,2) NULL
);
