
USE [StockDB]
GO

/****** Object:  Table [Analysis].[PatternPredictionResults]    Script Date: 18/10/2025 2:57:55 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Analysis].[PatternPredictionResults](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[PredictionDate] [date] NOT NULL,
	[PredictionTimestamp] [datetime2](3) NOT NULL,
	[ASXCode] [nvarchar](10) NOT NULL,
	[ConfidenceScore] [decimal](5, 4) NULL,
	[EffectiveConfidence] [decimal](5, 4) NULL,
	[PenalizedConfidence] [decimal](5, 4) NULL,
	[Prediction] [nvarchar](20) NULL,
	[PatternType] [nvarchar](100) NULL,
	[DailyPattern] [nvarchar](max) NULL,
	[WeeklyPattern] [nvarchar](max) NULL,
	[SMAConfluence] [nvarchar](50) NULL,
	[RiskLevel] [nvarchar](20) NULL,
	[NextDayBias] [nvarchar](50) NULL,
	[ExtensionRisk] [nvarchar](50) NULL,
	[AnalysisText] [nvarchar](max) NULL,
	[ChartPath] [nvarchar](500) NULL,
	[ChartFilename] [nvarchar](255) NULL,
	[ModelName] [nvarchar](100) NULL,
	[ThresholdUsed] [decimal](3, 2) NULL,
	[BatchRunID] [nvarchar](50) NULL,
	[CreatedDate] [datetime2](3) NOT NULL,
	[ModifiedDate] [datetime2](3) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [Analysis].[PatternPredictionResults] ADD  DEFAULT (getdate()) FOR [PredictionTimestamp]
GO

ALTER TABLE [Analysis].[PatternPredictionResults] ADD  DEFAULT (getdate()) FOR [CreatedDate]
GO

ALTER TABLE [Analysis].[PatternPredictionResults] ADD  DEFAULT (getdate()) FOR [ModifiedDate]
GO

ALTER TABLE [Analysis].[PatternPredictionResults]  WITH CHECK ADD  CONSTRAINT [CK_PatternPredictionResults_ConfidenceRange] CHECK  (([ConfidenceScore]>=(0) AND [ConfidenceScore]<=(1) OR [ConfidenceScore] IS NULL))
GO

ALTER TABLE [Analysis].[PatternPredictionResults] CHECK CONSTRAINT [CK_PatternPredictionResults_ConfidenceRange]
GO

ALTER TABLE [Analysis].[PatternPredictionResults]  WITH CHECK ADD  CONSTRAINT [CK_PatternPredictionResults_EffectiveConfidenceRange] CHECK  (([EffectiveConfidence]>=(0) AND [EffectiveConfidence]<=(1) OR [EffectiveConfidence] IS NULL))
GO

ALTER TABLE [Analysis].[PatternPredictionResults] CHECK CONSTRAINT [CK_PatternPredictionResults_EffectiveConfidenceRange]
GO

ALTER TABLE [Analysis].[PatternPredictionResults]  WITH CHECK ADD  CONSTRAINT [CK_PatternPredictionResults_Prediction] CHECK  (([Prediction]='unknown' OR [Prediction]='neutral' OR [Prediction]='bearish' OR [Prediction]='bullish' OR [Prediction] IS NULL))
GO

ALTER TABLE [Analysis].[PatternPredictionResults] CHECK CONSTRAINT [CK_PatternPredictionResults_Prediction]
GO

ALTER TABLE [Analysis].[PatternPredictionResults]  WITH CHECK ADD  CONSTRAINT [CK_PatternPredictionResults_ThresholdRange] CHECK  (([ThresholdUsed]>=(0) AND [ThresholdUsed]<=(1) OR [ThresholdUsed] IS NULL))
GO

ALTER TABLE [Analysis].[PatternPredictionResults] CHECK CONSTRAINT [CK_PatternPredictionResults_ThresholdRange]
GO


