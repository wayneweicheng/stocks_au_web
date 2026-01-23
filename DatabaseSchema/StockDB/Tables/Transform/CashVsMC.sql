-- Table: [Transform].[CashVsMC]

CREATE TABLE [Transform].[CashVsMC] (
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL,
    [CashVsMC] [decimal](10,3) NULL,
    [CashPosition] [numeric](26,6) NULL,
    [MC] [numeric](23,3) NULL,
    [ASXCode] [varchar](10) NOT NULL
,
    CONSTRAINT [pk_transformcashvsmc_uniquekey] PRIMARY KEY (UniqueKey)
);
