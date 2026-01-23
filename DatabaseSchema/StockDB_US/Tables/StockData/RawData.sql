-- Table: [StockData].[RawData]

CREATE TABLE [StockData].[RawData] (
    [RawDataID] [int] IDENTITY(1,1) NOT NULL,
    [DataTypeID] [tinyint] NOT NULL,
    [RawData] [varchar](MAX) NOT NULL,
    [CreateDate] [datetime] NOT NULL,
    [SourceSystemDate] [datetime] NULL,
    [WatchListName] [varchar](100) NULL
,
    CONSTRAINT [pk_stockdatarawdata_rawdataid] PRIMARY KEY (RawDataID)
);
