-- Table: [StockData].[DirectorCurrentPvt]

CREATE TABLE [StockData].[DirectorCurrentPvt] (
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [DirName] [nvarchar](MAX) NULL
,
    CONSTRAINT [pk_stockdata_directorcurrentpvt_uniquekey] PRIMARY KEY (UniqueKey)
);
