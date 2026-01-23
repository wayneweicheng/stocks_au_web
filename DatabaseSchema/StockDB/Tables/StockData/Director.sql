-- Table: [StockData].[Director]

CREATE TABLE [StockData].[Director] (
    [DirectorID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Name] [varchar](200) NOT NULL,
    [Age] [int] NULL,
    [Since] [int] NULL,
    [Position] [varchar](200) NOT NULL,
    [DateFrom] [smalldatetime] NOT NULL,
    [DateTo] [smalldatetime] NULL,
    [DateLastSeen] [smalldatetime] NULL
,
    CONSTRAINT [pk_stockdatadirector_directorid] PRIMARY KEY (DirectorID)
);
