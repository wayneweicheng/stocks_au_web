-- Table: [HC].[PosterPerf]

CREATE TABLE [HC].[PosterPerf] (
    [Poster] [varchar](200) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [StartTime] [smalldatetime] NOT NULL,
    [PriceAtPosting] [varchar](100) NULL,
    [EndTime] [smalldatetime] NULL,
    [StartPrice] [decimal](20,4) NULL,
    [EndPrice] [decimal](20,4) NULL,
    [ClosePrice] [decimal](20,4) NULL,
    [HighPrice] [decimal](20,4) NULL,
    [LowPrice] [decimal](20,4) NULL,
    [PercGain] [decimal](10,2) NULL,
    [OpenPosition] [decimal](20,4) NULL,
    [ClosePosition] [decimal](20,4) NULL,
    [Duration] [int] NULL,
    [PercGainPerYear] [decimal](10,2) NULL
);
