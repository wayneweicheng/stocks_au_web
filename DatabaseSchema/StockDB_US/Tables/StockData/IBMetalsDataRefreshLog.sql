-- Table: [StockData].[IBMetalsDataRefreshLog]

CREATE TABLE [StockData].[IBMetalsDataRefreshLog] (
    [ID] [bigint] IDENTITY(1,1) NOT NULL,
    [RefreshDateTime] [datetime] NOT NULL,
    [Metal] [varchar](20) NOT NULL,
    [RecordsInserted] [int] NOT NULL DEFAULT ((0)),
    [RecordsUpdated] [int] NOT NULL DEFAULT ((0)),
    [UnderlyingPrice] [decimal](18,6) NULL,
    [TotalContracts] [int] NULL,
    [ContractsWithOI] [int] NULL,
    [ContractsWithVolume] [int] NULL,
    [ExecutionTimeSeconds] [int] NULL,
    [Status] [varchar](20) NOT NULL,
    [ErrorMessage] [nvarchar](MAX) NULL,
    [CreateDate] [datetime] NULL DEFAULT (getdate())
,
    CONSTRAINT [PK__IBMetals__3214EC27410978B7] PRIMARY KEY (ID)
);

CREATE INDEX [IX_IBMetalsDataRefreshLog_RefreshDateTime] ON [StockData].[IBMetalsDataRefreshLog] (Metal, Status, RecordsInserted, RefreshDateTime);