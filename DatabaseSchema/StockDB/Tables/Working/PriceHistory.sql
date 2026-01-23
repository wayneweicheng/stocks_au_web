-- Table: [Working].[PriceHistory]

CREATE TABLE [Working].[PriceHistory] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [Close] [decimal](20,4) NOT NULL,
    [Open] [decimal](20,4) NOT NULL,
    [Low] [decimal](20,4) NOT NULL,
    [High] [decimal](20,4) NOT NULL,
    [Volume] [bigint] NOT NULL,
    [Value] [decimal](20,4) NULL,
    [Trades] [int] NULL,
    [VWAP] [decimal](31,15) NULL,
    [PrevClose] [decimal](20,4) NULL,
    [PriceChangeVsPrevClose] [decimal](20,4) NULL,
    [PriceChangeVsOpen] [decimal](10,2) NULL,
    [Spread] [decimal](21,4) NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [ModifyDate] [smalldatetime] NULL,
    [TransformDate] [datetime] NULL,
    [Year] [int] NOT NULL,
    [WeekOfYear] [tinyint] NOT NULL,
    [Weekday] [tinyint] NOT NULL
);
