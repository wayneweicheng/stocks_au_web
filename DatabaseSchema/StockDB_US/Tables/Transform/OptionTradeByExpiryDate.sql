-- Table: [Transform].[OptionTradeByExpiryDate]

CREATE TABLE [Transform].[OptionTradeByExpiryDate] (
    [ObservationDate] [date] NULL,
    [ExpiryDate] [date] NULL,
    [MoneyType] [varchar](5) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ShortLongRatio] [numeric](38,6) NULL,
    [ShortSize] [bigint] NULL,
    [LongSize] [bigint] NULL,
    [CreateDate] [smalldatetime] NULL,
    [ShortGEX] [bigint] NULL,
    [LongGEX] [bigint] NULL,
    [ShortMinusLongSize] [bigint] NULL,
    [ShortMinusLongGEX] [bigint] NULL
);
