-- Table: [StockData].[DirectorCurrent]

CREATE TABLE [StockData].[DirectorCurrent] (
    [DirectorCurrentId] [int] IDENTITY(1,1) NOT NULL,
    [DirectorID] [int] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Name] [varchar](200) NOT NULL,
    [FirstName] [varchar](200) NULL,
    [MiddleName] [varchar](200) NULL,
    [Surname] [varchar](200) NULL,
    [Age] [int] NULL,
    [Since] [int] NULL,
    [Position] [varchar](200) NOT NULL,
    [UniqueKey] [int] NOT NULL,
    [DedupeKey] [int] NOT NULL
,
    CONSTRAINT [pk_stockdata_directorcurrent_directorcurrentid] PRIMARY KEY (DirectorCurrentId)
);
