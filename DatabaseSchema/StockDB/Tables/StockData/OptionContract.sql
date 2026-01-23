-- Table: [StockData].[OptionContract]

CREATE TABLE [StockData].[OptionContract] (
    [OptionContractID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Underlying] [varchar](10) NOT NULL,
    [OptionSymbol] [varchar](100) NOT NULL,
    [Currency] [varchar](50) NOT NULL,
    [Strike] [decimal](20,4) NULL,
    [PorC] [varchar](10) NULL,
    [Multiplier] [int] NULL,
    [Expiry] [varchar](20) NULL,
    [ExpiryDate] [date] NULL,
    [Bid] [decimal](20,4) NULL,
    [BidSize] [bigint] NULL,
    [Ask] [decimal](20,4) NULL,
    [AskSize] [bigint] NULL,
    [Close] [decimal](20,4) NULL,
    [Delta] [decimal](20,4) NULL,
    [Gamma] [decimal](20,4) NULL,
    [Vega] [decimal](20,4) NULL,
    [Theta] [decimal](20,4) NULL,
    [ImpliedVol] [decimal](20,4) NULL,
    [CreateDateTime] [smalldatetime] NULL,
    [UpdateDateTime] [smalldatetime] NULL
);
