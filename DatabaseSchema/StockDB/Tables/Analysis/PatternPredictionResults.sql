-- Table: [Analysis].[PatternPredictionResults]

CREATE TABLE [Analysis].[PatternPredictionResults] (
    [ID] [bigint] IDENTITY(1,1) NOT NULL,
    [PredictionDate] [date] NOT NULL,
    [PredictionTimestamp] [datetime2] NOT NULL DEFAULT (getdate()),
    [ASXCode] [nvarchar](10) NOT NULL,
    [ConfidenceScore] [decimal](5,4) NULL,
    [EffectiveConfidence] [decimal](5,4) NULL,
    [PenalizedConfidence] [decimal](5,4) NULL,
    [Prediction] [nvarchar](20) NULL,
    [PatternType] [nvarchar](100) NULL,
    [DailyPattern] [nvarchar](MAX) NULL,
    [WeeklyPattern] [nvarchar](MAX) NULL,
    [SMAConfluence] [nvarchar](50) NULL,
    [RiskLevel] [nvarchar](20) NULL,
    [NextDayBias] [nvarchar](50) NULL,
    [ExtensionRisk] [nvarchar](50) NULL,
    [AnalysisText] [nvarchar](MAX) NULL,
    [ChartPath] [nvarchar](500) NULL,
    [ChartFilename] [nvarchar](255) NULL,
    [ModelName] [nvarchar](100) NULL,
    [ThresholdUsed] [decimal](3,2) NULL,
    [BatchRunID] [nvarchar](50) NULL,
    [CreatedDate] [datetime2] NOT NULL DEFAULT (getdate()),
    [ModifiedDate] [datetime2] NOT NULL DEFAULT (getdate())
,
    CONSTRAINT [PK__PatternP__3214EC276990ABCF] PRIMARY KEY (ID)
);

CREATE INDEX [IX_PatternPredictionResults_BatchRunID] ON [Analysis].[PatternPredictionResults] (BatchRunID);
CREATE INDEX [IX_PatternPredictionResults_ConfidenceScore] ON [Analysis].[PatternPredictionResults] (ConfidenceScore);
CREATE INDEX [IX_PatternPredictionResults_PredictionDate_ASXCode] ON [Analysis].[PatternPredictionResults] (PredictionDate, ASXCode);
CREATE INDEX [IX_PatternPredictionResults_PredictionTimestamp] ON [Analysis].[PatternPredictionResults] (PredictionTimestamp);