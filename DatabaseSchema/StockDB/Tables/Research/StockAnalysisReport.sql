-- Table: [Research].[StockAnalysisReport]

CREATE TABLE [Research].[StockAnalysisReport] (
    [ReportID] [int] IDENTITY(1,1) NOT NULL,
    [StockCode] [varchar](20) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [ReportMarkdown] [nvarchar](MAX) NULL,
    [ReportJSON] [nvarchar](MAX) NULL,
    [Model] [varchar](100) NULL,
    [Status] [varchar](20) NOT NULL DEFAULT 'Completed',
    [ProcessedAt] [datetime] NOT NULL DEFAULT (getdate()),
    [ProcessedBy] [varchar](50) NULL,
    [TokensUsed] [int] NULL,
    [ProcessingTimeSeconds] [decimal](10,2) NULL
,
    CONSTRAINT [PK_StockAnalysisReport] PRIMARY KEY CLUSTERED ([ReportID] ASC)
);

CREATE INDEX [IX_StockAnalysisReport_StockCode] ON [Research].[StockAnalysisReport] ([StockCode]);
CREATE INDEX [IX_StockAnalysisReport_ObservationDate] ON [Research].[StockAnalysisReport] ([ObservationDate]);
CREATE UNIQUE INDEX [IX_StockAnalysisReport_StockCode_ObservationDate] ON [Research].[StockAnalysisReport] ([StockCode], [ObservationDate]);
