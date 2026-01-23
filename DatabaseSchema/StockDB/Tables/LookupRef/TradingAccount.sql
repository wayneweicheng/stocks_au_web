-- Table: [LookupRef].[TradingAccount]

CREATE TABLE [LookupRef].[TradingAccount] (
    [TradingPlatform] [varchar](20) NOT NULL,
    [TradeAccountName] [varchar](100) NOT NULL,
    [AccountNumber] [varchar](50) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_lookupreftradingaccount_tradingplatformtradeaccountname] PRIMARY KEY (TradingPlatform, TradeAccountName)
);
