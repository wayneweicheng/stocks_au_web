-- Table: [StockData].[Top20Holder]

CREATE TABLE [StockData].[Top20Holder] (
    [Top20HolderID] [bigint] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [NumberOfSecurity] [bigint] NULL,
    [HolderName] [varchar](500) NULL,
    [CurrDate] [date] NULL,
    [PrevDate] [date] NULL,
    [CurrRank] [int] NULL,
    [PrevRank] [int] NULL,
    [CurrShares] [bigint] NULL,
    [PrevShares] [bigint] NULL,
    [CurrSharesPerc] [decimal](20,4) NULL,
    [PrevSharesPerc] [decimal](20,4) NULL,
    [ShareDiff] [bigint] NULL,
    [CreateDate] [smalldatetime] NOT NULL
);
