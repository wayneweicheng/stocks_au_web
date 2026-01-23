-- Table: [Transform].[MarketCLVTrend]

CREATE TABLE [Transform].[MarketCLVTrend] (
    [MarketCap] [varchar](14) NULL,
    [ObservationDate] [date] NOT NULL,
    [CLV] [decimal](38,6) NULL,
    [CLVMA5] [decimal](10,4) NULL,
    [CLVMA10] [decimal](10,4) NULL,
    [CLVMA20] [decimal](10,4) NULL,
    [VarCLVMA5] [decimal](10,2) NULL,
    [VarCLVMA10] [decimal](10,2) NULL,
    [VarCLVMA20] [decimal](10,2) NULL,
    [NumObservation] [int] NULL,
    [CreateDate] [datetime] NOT NULL,
    [XAO] [decimal](20,4) NULL,
    [XAOChange] [decimal](10,2) NULL,
    [Sector] [varchar](3) NOT NULL
);
