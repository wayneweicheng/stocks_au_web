-- Table: [Transform].[OptionTradeByExpiryDateHistory]

CREATE TABLE [Transform].[OptionTradeByExpiryDateHistory] (
    [ObservationDate] [date] NULL,
    [ExpiryDate] [date] NULL,
    [MoneyType] [varchar](5) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ShortLongRatio] [numeric](38,6) NULL,
    [ShortSize] [bigint] NULL,
    [LongSize] [bigint] NULL,
    [CreateDate] [smalldatetime] NULL,
    [ArchiveDate] [smalldatetime] NOT NULL,
    [ShortGEX] [bigint] NULL,
    [LongGEX] [bigint] NULL,
    [ShortMinusLongSize] [bigint] NULL,
    [ShortMinusLongGEX] [bigint] NULL
);
