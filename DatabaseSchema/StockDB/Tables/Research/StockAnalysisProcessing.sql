-- Table: [Research].[StockAnalysisProcessing]

CREATE TABLE [Research].[StockAnalysisProcessing] (
    [ProcessingID] [int] IDENTITY(1,1) NOT NULL,
    [StockCode] [varchar](20) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [Status] [varchar](20) NOT NULL DEFAULT 'Pending',
    [StartedAt] [datetime] NULL,
    [CompletedAt] [datetime] NULL,
    [ErrorMessage] [nvarchar](MAX) NULL,
    [RequestedBy] [varchar](50) NULL,
    [Model] [varchar](100) NULL
,
    CONSTRAINT [PK_StockAnalysisProcessing] PRIMARY KEY CLUSTERED ([ProcessingID] ASC)
);

CREATE INDEX [IX_StockAnalysisProcessing_StockCode] ON [Research].[StockAnalysisProcessing] ([StockCode]);
CREATE INDEX [IX_StockAnalysisProcessing_Status] ON [Research].[StockAnalysisProcessing] ([Status]);
CREATE UNIQUE INDEX [IX_StockAnalysisProcessing_StockCode_ObservationDate_Active]
    ON [Research].[StockAnalysisProcessing] ([StockCode], [ObservationDate])
    WHERE [Status] IN ('Pending', 'Processing');
