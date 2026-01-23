-- Table: [StockData].[OptionTrade]

CREATE TABLE [StockData].[OptionTrade] (
    [OptionTradeID] [bigint] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Underlying] [varchar](10) NOT NULL,
    [OptionSymbol] [varchar](100) NOT NULL,
    [SaleTime] [datetime] NULL,
    [Price] [decimal](20,4) NULL,
    [Size] [bigint] NULL,
    [Exchange] [varchar](100) NULL,
    [SpecialConditions] [varchar](200) NULL,
    [CreateDateTime] [smalldatetime] NULL,
    [UpdateDateTime] [smalldatetime] NULL,
    [BuySellIndicator] [char](1) NULL,
    [LongShortIndicator] [varchar](10) NULL,
    [ObservationDateLocal] [date] NULL,
    [QueryBidAskAt] [datetime] NULL,
    [Strike] [decimal](20,4) NULL,
    [PorC] [char](1) NULL,
    [ExpiryDate] [date] NULL,
    [Expiry] [varchar](8) NULL,
    [QueryBidNum] [int] NULL
);

CREATE INDEX [idx_stockdata_optiontrade] ON [StockData].[OptionTrade] (ASXCode, CreateDateTime);
CREATE INDEX [idx_stockdataoptiontrade_asxcodeIncoptionsymbolsaletimepricesize] ON [StockData].[OptionTrade] (OptionSymbol, SaleTime, Price, Size, ASXCode);
CREATE INDEX [idx_stockdataoptiontrade_obdatelocaloptionsymbol] ON [StockData].[OptionTrade] (ObservationDateLocal, OptionSymbol);
CREATE INDEX [idx_stockdataoptiontrade_optionsymbolasxcodeunderlyingIncsaletimepricesize] ON [StockData].[OptionTrade] (SaleTime, Price, Size, Exchange, SpecialConditions, OptionSymbol, ASXCode, Underlying);