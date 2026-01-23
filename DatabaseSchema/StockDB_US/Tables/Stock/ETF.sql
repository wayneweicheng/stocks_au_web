-- Table: [Stock].[ETF]

CREATE TABLE [Stock].[ETF] (
    [ASXCode] [varchar](10) NOT NULL,
    [ETFName] [varchar](200) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [IsDisabled] [bit] NULL,
    [ETFID] [int] IDENTITY(1,1) NOT NULL,
    [RankOrder] [int] NULL
,
    CONSTRAINT [pk_stocketf_asxcode] PRIMARY KEY (ASXCode)
);
