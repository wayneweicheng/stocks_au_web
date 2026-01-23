-- Table: [Transform].[v_OptionDelayedQuote_All_V2]

CREATE TABLE [Transform].[v_OptionDelayedQuote_All_V2] (
    [Strike] [decimal](20,4) NULL,
    [PorC] [char](1) NULL,
    [ExpiryDate] [date] NULL,
    [Expiry] [varchar](8) NULL,
    [ASXCode] [varchar](10) NULL,
    [ObservationDate] [date] NULL,
    [OptionSymbol] [varchar](200) NULL,
    [Bid] [decimal](20,4) NULL,
    [BidSize] [decimal](20,4) NULL,
    [Ask] [decimal](20,4) NULL,
    [AskSize] [decimal](20,4) NULL,
    [IV] [decimal](20,4) NULL,
    [OpenInterest] [decimal](20,4) NULL,
    [Volume] [decimal](20,4) NULL,
    [Delta] [decimal](20,4) NULL,
    [Gamma] [decimal](20,4) NULL,
    [Theta] [decimal](20,4) NULL,
    [RHO] [decimal](20,4) NULL,
    [Vega] [decimal](20,4) NULL,
    [Theo] [decimal](20,4) NULL,
    [Change] [decimal](20,4) NULL,
    [Open] [decimal](20,4) NULL,
    [High] [decimal](20,4) NULL,
    [Low] [decimal](20,4) NULL,
    [Tick] [varchar](100) NULL,
    [LastTradePrice] [decimal](20,4) NULL,
    [LastTradeTime] [datetime] NULL,
    [PrevDayClose] [varchar](100) NULL,
    [CreateDate] [smalldatetime] NULL,
    [Prev1OpenInterest] [decimal](20,4) NULL,
    [Prev1Delta] [decimal](20,4) NULL,
    [Prev1Gamma] [decimal](20,4) NULL
);

CREATE INDEX [idx_transformoptiondelayquoteallv2_asxcodeobdate] ON [Transform].[v_OptionDelayedQuote_All_V2] (ASXCode, ObservationDate);