-- Table: [Research].[StockAnalysisReportRating]
-- Stores structured overall rating and aspect scores extracted from stock analysis reports

CREATE TABLE [Research].[StockAnalysisReportRating] (
    [RatingID] [int] IDENTITY(1,1) NOT NULL,
    [ReportID] [int] NOT NULL,
    [StockCode] [varchar](20) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [OverallScore] [int] NULL,
    [OverallRating] [varchar](50) NULL,
    [FundamentalScore] [int] NULL,
    [FundamentalRating] [varchar](50) NULL,
    [NewsflowScore] [int] NULL,
    [NewsflowRating] [varchar](50) NULL,
    [TechnicalScore] [int] NULL,
    [TechnicalRating] [varchar](50) NULL,
    [BrokerScore] [int] NULL,
    [BrokerRating] [varchar](50) NULL,
    [CreatedAt] [datetime] NOT NULL DEFAULT (getdate())
,
    CONSTRAINT [PK_StockAnalysisReportRating] PRIMARY KEY CLUSTERED ([RatingID] ASC),
    CONSTRAINT [FK_StockAnalysisReportRating_Report] FOREIGN KEY ([ReportID])
        REFERENCES [Research].[StockAnalysisReport] ([ReportID])
        ON DELETE CASCADE
);

CREATE UNIQUE INDEX [IX_StockAnalysisReportRating_ReportID] ON [Research].[StockAnalysisReportRating] ([ReportID]);
CREATE INDEX [IX_StockAnalysisReportRating_StockCode] ON [Research].[StockAnalysisReportRating] ([StockCode]);
CREATE INDEX [IX_StockAnalysisReportRating_ObservationDate] ON [Research].[StockAnalysisReportRating] ([ObservationDate]);
