-- Table: [StockData].[StockStatsHistory]

CREATE TABLE [StockData].[StockStatsHistory] (
    [StockStatsHistoryID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [Close] [decimal](20,4) NOT NULL,
    [Open] [decimal](20,4) NOT NULL,
    [Low] [decimal](20,4) NOT NULL,
    [High] [decimal](20,4) NOT NULL,
    [PrevClose] [decimal](20,4) NULL,
    [Volume] [bigint] NOT NULL,
    [IsTrendFlatOrUp] [bit] NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [LastUpdateDate] [smalldatetime] NOT NULL,
    [DateSeq] [int] NULL
,
    CONSTRAINT [pk_stockdatastockstatshistory_stockstatshistoryid] PRIMARY KEY (StockStatsHistoryID)
);

CREATE INDEX [idx_stockdatastockstatshistory_asxcodeobservationdate] ON [StockData].[StockStatsHistory] (ASXCode, ObservationDate);