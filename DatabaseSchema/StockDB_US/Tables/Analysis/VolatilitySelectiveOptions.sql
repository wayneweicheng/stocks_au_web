/*
    AI Volatility-Selective Options - non-executing research/monitoring schema.
    This file creates audit and manual-position storage only. It does not create
    broker orders and does not submit or modify IBKR orders.
*/

IF OBJECT_ID(N'[Analysis].[VolatilitySelectiveScan]', N'U') IS NULL
BEGIN
    CREATE TABLE [Analysis].[VolatilitySelectiveScan] (
        [ScanId] bigint IDENTITY(1,1) NOT NULL,
        [RunId] nvarchar(100) NOT NULL,
        [AsAt] datetimeoffset(0) NOT NULL,
        [EvidenceCutoff] date NULL,
        [Mode] nvarchar(30) NOT NULL CONSTRAINT [DF_VSOScan_Mode] DEFAULT ('research_shadow'),
        [Status] nvarchar(20) NOT NULL CONSTRAINT [DF_VSOScan_Status] DEFAULT ('QUEUED'),
        [Symbols] nvarchar(1000) NULL,
        [AccountEquity] decimal(19,4) NULL,
        [AssignmentExposure] decimal(19,4) NULL,
        [CandidateCount] int NULL,
        [DisplayedCandidateCount] int NULL,
        [ReportPath] nvarchar(1000) NULL,
        [SummaryJson] nvarchar(max) NULL,
        [ErrorMessage] nvarchar(2000) NULL,
        [CreatedAt] datetime2(0) NOT NULL CONSTRAINT [DF_VSOScan_CreatedAt] DEFAULT (getutcdate()),
        [CompletedAt] datetime2(0) NULL,
        CONSTRAINT [PK_VolatilitySelectiveScan] PRIMARY KEY CLUSTERED ([ScanId]),
        CONSTRAINT [UQ_VolatilitySelectiveScan_RunId] UNIQUE ([RunId])
    );
END;
GO

IF OBJECT_ID(N'[Analysis].[VolatilitySelectiveSnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [Analysis].[VolatilitySelectiveSnapshot] (
        [SnapshotId] bigint IDENTITY(1,1) NOT NULL,
        [RunId] nvarchar(100) NOT NULL,
        [Symbol] nvarchar(20) NOT NULL,
        [AsAt] datetimeoffset(0) NOT NULL,
        [EvidenceCutoff] date NULL,
        [Spot] decimal(19,6) NULL,
        [ForecastRV] decimal(19,8) NULL,
        [ForecastUncertainty] decimal(19,8) NULL,
        [ATMIV] decimal(19,8) NULL,
        [TermStructure] nvarchar(40) NULL,
        [Regime] nvarchar(80) NULL,
        [SnapshotJson] nvarchar(max) NOT NULL,
        [CreatedAt] datetime2(0) NOT NULL CONSTRAINT [DF_VSOSnapshot_CreatedAt] DEFAULT (getutcdate()),
        CONSTRAINT [PK_VolatilitySelectiveSnapshot] PRIMARY KEY CLUSTERED ([SnapshotId])
    );
END;
GO

IF OBJECT_ID(N'[Analysis].[VolatilitySelectiveCandidate]', N'U') IS NULL
BEGIN
    CREATE TABLE [Analysis].[VolatilitySelectiveCandidate] (
        [CandidateId] bigint IDENTITY(1,1) NOT NULL,
        [RunId] nvarchar(100) NOT NULL,
        [Rank] int NULL,
        [Symbol] nvarchar(20) NOT NULL,
        [Strategy] nvarchar(40) NOT NULL,
        [Expiration] date NOT NULL,
        [DTE] int NOT NULL,
        [ShortOption] nvarchar(100) NULL,
        [ShortStrike] decimal(19,6) NULL,
        [LongOption] nvarchar(100) NULL,
        [LongStrike] decimal(19,6) NULL,
        [Credit] decimal(19,6) NULL,
        [TradeScore] decimal(12,6) NULL,
        [VolatilityEdge] decimal(19,8) NULL,
        [ForecastRV] decimal(19,8) NULL,
        [ShortIV] decimal(19,8) NULL,
        [PutSkew] decimal(19,8) NULL,
        [Delta] decimal(19,8) NULL,
        [Gamma] decimal(19,8) NULL,
        [Theta] decimal(19,8) NULL,
        [Vega] decimal(19,8) NULL,
        [MaxLoss] decimal(19,4) NULL,
        [WorstScenarioLoss] decimal(19,4) NULL,
        [CVaR95] decimal(19,4) NULL,
        [AssignmentNotional] decimal(19,4) NULL,
        [Decision] nvarchar(20) NOT NULL CONSTRAINT [DF_VSOCandidate_Decision] DEFAULT ('PASS'),
        [CandidateJson] nvarchar(max) NOT NULL,
        [CreatedAt] datetime2(0) NOT NULL CONSTRAINT [DF_VSOCandidate_CreatedAt] DEFAULT (getutcdate()),
        CONSTRAINT [PK_VolatilitySelectiveCandidate] PRIMARY KEY CLUSTERED ([CandidateId])
    );
END;
GO

IF OBJECT_ID(N'[Analysis].[VolatilitySelectiveManualPosition]', N'U') IS NULL
BEGIN
    CREATE TABLE [Analysis].[VolatilitySelectiveManualPosition] (
        [PositionId] bigint IDENTITY(1,1) NOT NULL,
        [RunId] nvarchar(100) NULL,
        [CandidateId] bigint NULL,
        [Symbol] nvarchar(20) NOT NULL,
        [Strategy] nvarchar(40) NOT NULL,
        [ShortOption] nvarchar(100) NOT NULL,
        [LongOption] nvarchar(100) NULL,
        [Expiration] date NOT NULL,
        [ShortStrike] decimal(19,6) NOT NULL,
        [LongStrike] decimal(19,6) NULL,
        [Quantity] int NOT NULL,
        [EntryCredit] decimal(19,6) NOT NULL,
        [EntrySpot] decimal(19,6) NULL,
        [ProfitCaptureTarget] decimal(8,6) NOT NULL CONSTRAINT [DF_VSOPosition_ProfitTarget] DEFAULT (0.60),
        [TimeExitDTE] int NOT NULL CONSTRAINT [DF_VSOPosition_TimeExitDTE] DEFAULT (14),
        [RiskDeltaExit] decimal(8,6) NOT NULL CONSTRAINT [DF_VSOPosition_RiskDelta] DEFAULT (0.45),
        [Status] nvarchar(20) NOT NULL CONSTRAINT [DF_VSOPosition_Status] DEFAULT ('OPEN'),
        [CurrentSpot] decimal(19,6) NULL,
        [CurrentIV] decimal(19,8) NULL,
        [CurrentValue] decimal(19,6) NULL,
        [UnrealizedPnL] decimal(19,4) NULL,
        [ExitRecommendation] nvarchar(40) NULL,
        [LastMonitoredAt] datetime2(0) NULL,
        [ClosedAt] datetime2(0) NULL,
        [CloseReason] nvarchar(200) NULL,
        [Notes] nvarchar(2000) NULL,
        [CreatedAt] datetime2(0) NOT NULL CONSTRAINT [DF_VSOPosition_CreatedAt] DEFAULT (getutcdate()),
        [UpdatedAt] datetime2(0) NOT NULL CONSTRAINT [DF_VSOPosition_UpdatedAt] DEFAULT (getutcdate()),
        CONSTRAINT [PK_VolatilitySelectiveManualPosition] PRIMARY KEY CLUSTERED ([PositionId]),
        CONSTRAINT [CK_VSOPosition_Quantity] CHECK ([Quantity] > 0),
        CONSTRAINT [CK_VSOPosition_EntryCredit] CHECK ([EntryCredit] >= 0),
        CONSTRAINT [CK_VSOPosition_Strategy] CHECK ([Strategy] IN ('short_put', 'bull_put_spread')),
        CONSTRAINT [CK_VSOPosition_Status] CHECK ([Status] IN ('OPEN', 'CLOSED', 'CANCELLED'))
    );
END;
GO

IF COL_LENGTH(N'[Analysis].[VolatilitySelectiveManualPosition]', N'CurrentDelta') IS NULL
    ALTER TABLE [Analysis].[VolatilitySelectiveManualPosition] ADD [CurrentDelta] decimal(19,8) NULL;
IF COL_LENGTH(N'[Analysis].[VolatilitySelectiveManualPosition]', N'CurrentGamma') IS NULL
    ALTER TABLE [Analysis].[VolatilitySelectiveManualPosition] ADD [CurrentGamma] decimal(19,8) NULL;
IF COL_LENGTH(N'[Analysis].[VolatilitySelectiveManualPosition]', N'CurrentTheta') IS NULL
    ALTER TABLE [Analysis].[VolatilitySelectiveManualPosition] ADD [CurrentTheta] decimal(19,8) NULL;
IF COL_LENGTH(N'[Analysis].[VolatilitySelectiveManualPosition]', N'CurrentVega') IS NULL
    ALTER TABLE [Analysis].[VolatilitySelectiveManualPosition] ADD [CurrentVega] decimal(19,8) NULL;

IF OBJECT_ID(N'[Analysis].[VolatilitySelectiveAlert]', N'U') IS NULL
BEGIN
    CREATE TABLE [Analysis].[VolatilitySelectiveAlert] (
        [AlertId] bigint IDENTITY(1,1) NOT NULL,
        [IdempotencyKey] nvarchar(300) NOT NULL,
        [RunId] nvarchar(100) NULL,
        [PositionId] bigint NULL,
        [AlertType] nvarchar(60) NOT NULL,
        [Severity] nvarchar(20) NOT NULL,
        [Title] nvarchar(200) NOT NULL,
        [Message] nvarchar(max) NOT NULL,
        [Status] nvarchar(20) NOT NULL CONSTRAINT [DF_VSOAlert_Status] DEFAULT ('PENDING'),
        [ProviderId] nvarchar(200) NULL,
        [LastError] nvarchar(2000) NULL,
        [CreatedAt] datetime2(0) NOT NULL CONSTRAINT [DF_VSOAlert_CreatedAt] DEFAULT (getutcdate()),
        [SentAt] datetime2(0) NULL,
        CONSTRAINT [PK_VolatilitySelectiveAlert] PRIMARY KEY CLUSTERED ([AlertId]),
        CONSTRAINT [UQ_VolatilitySelectiveAlert_Key] UNIQUE ([IdempotencyKey])
    );
END;
GO

IF OBJECT_ID(N'[Analysis].[VolatilitySelectiveBacktestRun]', N'U') IS NULL
BEGIN
    CREATE TABLE [Analysis].[VolatilitySelectiveBacktestRun] (
        [BacktestRunId] bigint IDENTITY(1,1) NOT NULL,
        [RunId] nvarchar(100) NOT NULL,
        [DatasetName] nvarchar(300) NULL,
        [StartDate] date NULL,
        [EndDate] date NULL,
        [Status] nvarchar(20) NOT NULL CONSTRAINT [DF_VSOBacktest_Status] DEFAULT ('SUCCEEDED'),
        [TradeCount] int NULL,
        [TotalPnL] decimal(19,4) NULL,
        [MaxDrawdown] decimal(19,4) NULL,
        [ProfitFactor] decimal(19,8) NULL,
        [MetricsJson] nvarchar(max) NOT NULL,
        [CreatedAt] datetime2(0) NOT NULL CONSTRAINT [DF_VSOBacktest_CreatedAt] DEFAULT (getutcdate()),
        CONSTRAINT [PK_VolatilitySelectiveBacktestRun] PRIMARY KEY CLUSTERED ([BacktestRunId]),
        CONSTRAINT [UQ_VolatilitySelectiveBacktest_RunId] UNIQUE ([RunId])
    );
END;
GO

IF OBJECT_ID(N'[Configuration].[VolatilitySelectiveSchedule]', N'U') IS NULL
BEGIN
    CREATE TABLE [Configuration].[VolatilitySelectiveSchedule] (
        [ScheduleId] int IDENTITY(1,1) NOT NULL,
        [ScheduleName] nvarchar(100) NOT NULL,
        [Enabled] bit NOT NULL CONSTRAINT [DF_VSOSchedule_Enabled] DEFAULT (0),
        [Symbols] nvarchar(1000) NOT NULL,
        [EventClearSymbols] nvarchar(1000) NULL,
        [AccountEquity] decimal(19,4) NOT NULL,
        [AssignmentExposure] decimal(19,4) NOT NULL CONSTRAINT [DF_VSOSchedule_Assignment] DEFAULT (0),
        [TopN] int NOT NULL CONSTRAINT [DF_VSOSchedule_TopN] DEFAULT (10),
        [DteMin] int NOT NULL CONSTRAINT [DF_VSOSchedule_DteMin] DEFAULT (30),
        [DteMax] int NOT NULL CONSTRAINT [DF_VSOSchedule_DteMax] DEFAULT (55),
        [MinimumVolatilityEdge] decimal(8,6) NOT NULL CONSTRAINT [DF_VSOSchedule_MinEdge] DEFAULT (0.02),
        [RiskBudgetPct] decimal(8,6) NOT NULL CONSTRAINT [DF_VSOSchedule_RiskBudget] DEFAULT (0.02),
        [MaxAssignmentExposurePct] decimal(8,6) NOT NULL CONSTRAINT [DF_VSOSchedule_MaxAssignment] DEFAULT (0.75),
        [Timezone] nvarchar(80) NOT NULL CONSTRAINT [DF_VSOSchedule_Timezone] DEFAULT ('America/New_York'),
        [CreatedAt] datetime2(0) NOT NULL CONSTRAINT [DF_VSOSchedule_CreatedAt] DEFAULT (getutcdate()),
        [UpdatedAt] datetime2(0) NOT NULL CONSTRAINT [DF_VSOSchedule_UpdatedAt] DEFAULT (getutcdate()),
        CONSTRAINT [PK_VolatilitySelectiveSchedule] PRIMARY KEY CLUSTERED ([ScheduleId]),
        CONSTRAINT [UQ_VolatilitySelectiveSchedule_Name] UNIQUE ([ScheduleName])
    );
END;
GO
