-- Table: [Transform].[MarketCLVTrendDetailsETF]

CREATE TABLE [Transform].[MarketCLVTrendDetailsETF] (
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
    [AdditionalElements] [varchar](MAX) NULL,
    [IsSPX500] [bit] NULL,
    [IsDJIA30] [bit] NULL,
    [IsNASDAQ100] [bit] NULL,
    [CLV] [decimal](10,4) NULL,
    [MarketCap] [varchar](50) NULL,
    [RowNumber] [bigint] NULL
);
