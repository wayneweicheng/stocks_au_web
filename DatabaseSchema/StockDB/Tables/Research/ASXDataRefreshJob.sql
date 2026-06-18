-- Table: [Research].[ASXDataRefreshJob]

CREATE TABLE [Research].[ASXDataRefreshJob] (
    [JobID] [int] IDENTITY(1,1) NOT NULL,
    [StockCode] [varchar](20) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [StartDate] [date] NOT NULL,
    [EndDate] [date] NOT NULL,
    [Status] [varchar](20) NOT NULL DEFAULT ('queued'),
    [CreatedAt] [datetime2] NOT NULL DEFAULT (sysutcdatetime()),
    [StartedAt] [datetime2] NULL,
    [CompletedAt] [datetime2] NULL,
    [ErrorMessage] [nvarchar](MAX) NULL,
    [RequestedBy] [varchar](50) NULL
,
    CONSTRAINT [PK_ASXDataRefreshJob] PRIMARY KEY (JobID)
);

CREATE INDEX [IX_ASXDataRefreshJob_ObservationDate] ON [Research].[ASXDataRefreshJob] (ObservationDate);
CREATE INDEX [IX_ASXDataRefreshJob_StockDate] ON [Research].[ASXDataRefreshJob] (StockCode, ObservationDate);