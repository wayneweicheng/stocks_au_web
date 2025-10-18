USE [StockDB]
GO

/****** Object:  Table [Analysis].[PLLRSScannerResults]    Script Date: 18/10/2025 3:42:19 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Analysis].[PLLRSScannerResults](
	[ASXCode] [nvarchar](10) NOT NULL,
	[ObservationDate] [date] NOT NULL,
	[OpenPrice] [decimal](18, 6) NULL,
	[ClosePrice] [decimal](18, 6) NOT NULL,
	[PrevClose] [decimal](18, 6) NULL,
	[TodayPriceChange] [decimal](18, 6) NULL,
	[MeetsCriteria] [bit] NOT NULL,
	[SupportPrice] [decimal](18, 6) NULL,
	[ResistancePrice] [decimal](18, 6) NULL,
	[DistanceToSupportPct] [decimal](18, 6) NULL,
	[NetAggressorFlow] [bigint] NULL,
	[AggressorBuyRatio] [decimal](18, 6) NULL,
	[BidAskReloadRatio] [decimal](18, 6) NULL,
	[TotalActiveBuyVolume] [bigint] NULL,
	[TotalActiveSellVolume] [bigint] NULL,
	[EntryPrice] [decimal](18, 6) NULL,
	[TargetPrice] [decimal](18, 6) NULL,
	[StopPrice] [decimal](18, 6) NULL,
	[PotentialGainPct] [decimal](18, 6) NULL,
	[PotentialLossPct] [decimal](18, 6) NULL,
	[RewardRiskRatio] [decimal](18, 6) NULL,
	[Reasons] [nvarchar](max) NULL,
	[ScanDateTime] [datetime2](7) NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_PLLRSScannerResults] PRIMARY KEY CLUSTERED 
(
	[ASXCode] ASC,
	[ObservationDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [Analysis].[PLLRSScannerResults] ADD  DEFAULT (getdate()) FOR [ScanDateTime]
GO

ALTER TABLE [Analysis].[PLLRSScannerResults] ADD  DEFAULT (getdate()) FOR [CreatedAt]
GO

ALTER TABLE [Analysis].[PLLRSScannerResults] ADD  DEFAULT (getdate()) FOR [UpdatedAt]
GO


