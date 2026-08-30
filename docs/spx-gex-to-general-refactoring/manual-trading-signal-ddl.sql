/*
    Manual DDL: StockDB_US.[TradingSignal]

    Apply manually only after:
      1. confirming the target SQL Server/database;
      2. taking a database backup;
      3. confirming StockDB and StockDB_US are on the same SQL Server instance;
      4. reviewing this script against the deployed DatabaseSchema conventions.

    This script creates tables, constraints, and indexes only. It deliberately
    does not create runtime stored procedures, views, permissions, seed data,
    or production Strategy Deployments. The smaller implementation model must
    implement and test those separately.

    The script is additive/idempotent for objects that do not already exist. If
    an object already exists with a different definition, stop and reconcile it;
    this script does not alter or drop existing objects.
*/

USE [StockDB_US];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

IF SCHEMA_ID(N'TradingSignal') IS NULL
    EXEC(N'CREATE SCHEMA [TradingSignal] AUTHORIZATION [dbo];');
GO

IF OBJECT_ID(N'[TradingSignal].[SchemaVersion]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[SchemaVersion]
    (
        [SchemaVersionID]     int IDENTITY(1,1) NOT NULL,
        [Component]           varchar(100) NOT NULL,
        [VersionCode]         varchar(50) NOT NULL,
        [Description]         nvarchar(1000) NULL,
        [AppliedUtc]          datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_SchemaVersion_AppliedUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_TradingSignal_SchemaVersion] PRIMARY KEY CLUSTERED ([SchemaVersionID]),
        CONSTRAINT [UQ_TradingSignal_SchemaVersion_Component] UNIQUE ([Component])
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[StrategyDefinition]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[StrategyDefinition]
    (
        [StrategyDefinitionID] int IDENTITY(1,1) NOT NULL,
        [StrategyCode]         varchar(100) NOT NULL,
        [DisplayName]          nvarchar(200) NOT NULL,
        [Description]          nvarchar(2000) NULL,
        [IsEnabled]            bit NOT NULL CONSTRAINT [DF_TradingSignal_StrategyDefinition_IsEnabled] DEFAULT ((1)),
        [CreatedUtc]           datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_StrategyDefinition_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_TradingSignal_StrategyDefinition] PRIMARY KEY CLUSTERED ([StrategyDefinitionID]),
        CONSTRAINT [UQ_TradingSignal_StrategyDefinition_StrategyCode] UNIQUE ([StrategyCode])
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[StrategyVersion]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[StrategyVersion]
    (
        [StrategyVersionID]    bigint IDENTITY(1,1) NOT NULL,
        [StrategyDefinitionID] int NOT NULL,
        [VersionCode]          varchar(100) NOT NULL,
        [ImplementationKey]    varchar(200) NOT NULL,
        [ConfigurationJson]    nvarchar(max) NULL,
        [ConfigurationHash]    char(64) NOT NULL,
        [ResearchMetadataJson] nvarchar(max) NULL,
        [Status]               varchar(20) NOT NULL CONSTRAINT [DF_TradingSignal_StrategyVersion_Status] DEFAULT ('DRAFT'),
        [CreatedUtc]           datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_StrategyVersion_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_TradingSignal_StrategyVersion] PRIMARY KEY CLUSTERED ([StrategyVersionID]),
        CONSTRAINT [FK_TradingSignal_StrategyVersion_Definition] FOREIGN KEY ([StrategyDefinitionID]) REFERENCES [TradingSignal].[StrategyDefinition] ([StrategyDefinitionID]),
        CONSTRAINT [UQ_TradingSignal_StrategyVersion_DefinitionVersion] UNIQUE ([StrategyDefinitionID], [VersionCode]),
        CONSTRAINT [CK_TradingSignal_StrategyVersion_Status] CHECK ([Status] IN ('DRAFT', 'ACTIVE', 'RETIRED')),
        CONSTRAINT [CK_TradingSignal_StrategyVersion_ConfigurationJson] CHECK ([ConfigurationJson] IS NULL OR (ISJSON([ConfigurationJson]) = 1 AND DATALENGTH([ConfigurationJson]) <= 2097152)),
        CONSTRAINT [CK_TradingSignal_StrategyVersion_ResearchMetadataJson] CHECK ([ResearchMetadataJson] IS NULL OR (ISJSON([ResearchMetadataJson]) = 1 AND DATALENGTH([ResearchMetadataJson]) <= 2097152)),
        CONSTRAINT [CK_TradingSignal_StrategyVersion_ConfigurationHash] CHECK (LEN([ConfigurationHash]) = 64)
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[StrategyDeployment]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[StrategyDeployment]
    (
        [StrategyDeploymentID] bigint IDENTITY(1,1) NOT NULL,
        [StrategyVersionID]    bigint NOT NULL,
        [DeploymentKey]        varchar(200) NOT NULL,
        [EnvironmentType]      varchar(30) NOT NULL,
        [IsEnabled]            bit NOT NULL CONSTRAINT [DF_TradingSignal_StrategyDeployment_IsEnabled] DEFAULT ((0)),
        [ExecutionEnabled]     bit NOT NULL CONSTRAINT [DF_TradingSignal_StrategyDeployment_ExecutionEnabled] DEFAULT ((0)),
        [NotificationEnabled]  bit NOT NULL CONSTRAINT [DF_TradingSignal_StrategyDeployment_NotificationEnabled] DEFAULT ((0)),
        [ConfigurationJson]    nvarchar(max) NULL,
        [CreatedUtc]           datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_StrategyDeployment_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_TradingSignal_StrategyDeployment] PRIMARY KEY CLUSTERED ([StrategyDeploymentID]),
        CONSTRAINT [FK_TradingSignal_StrategyDeployment_Version] FOREIGN KEY ([StrategyVersionID]) REFERENCES [TradingSignal].[StrategyVersion] ([StrategyVersionID]),
        CONSTRAINT [UQ_TradingSignal_StrategyDeployment_DeploymentKey] UNIQUE ([DeploymentKey]),
        CONSTRAINT [CK_TradingSignal_StrategyDeployment_Environment] CHECK ([EnvironmentType] IN ('BACKTEST', 'MIGRATION_SHADOW', 'FORWARD_PAPER', 'LIVE_MANUAL')),
        CONSTRAINT [CK_TradingSignal_StrategyDeployment_ConfigurationJson] CHECK ([ConfigurationJson] IS NULL OR (ISJSON([ConfigurationJson]) = 1 AND DATALENGTH([ConfigurationJson]) <= 2097152))
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[ExecutionBook]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[ExecutionBook]
    (
        [ExecutionBookID]      bigint IDENTITY(1,1) NOT NULL,
        [StrategyDeploymentID] bigint NOT NULL,
        [BookKey]              varchar(200) NOT NULL,
        [EnvironmentType]      varchar(30) NOT NULL,
        [Cash]                 decimal(19,4) NOT NULL CONSTRAINT [DF_TradingSignal_ExecutionBook_Cash] DEFAULT ((0)),
        [Nav]                  decimal(19,4) NOT NULL CONSTRAINT [DF_TradingSignal_ExecutionBook_Nav] DEFAULT ((0)),
        [ExposureFactor]       decimal(19,8) NOT NULL CONSTRAINT [DF_TradingSignal_ExecutionBook_ExposureFactor] DEFAULT ((1)),
        [StateMetadataJson]    nvarchar(max) NULL,
        [CreatedUtc]           datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_ExecutionBook_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        [RowVersion]           rowversion NOT NULL,
        CONSTRAINT [PK_TradingSignal_ExecutionBook] PRIMARY KEY CLUSTERED ([ExecutionBookID]),
        CONSTRAINT [FK_TradingSignal_ExecutionBook_Deployment] FOREIGN KEY ([StrategyDeploymentID]) REFERENCES [TradingSignal].[StrategyDeployment] ([StrategyDeploymentID]),
        CONSTRAINT [UQ_TradingSignal_ExecutionBook_BookKey] UNIQUE ([BookKey]),
        CONSTRAINT [UQ_TradingSignal_ExecutionBook_DeploymentEnvironment] UNIQUE ([StrategyDeploymentID], [EnvironmentType]),
        CONSTRAINT [CK_TradingSignal_ExecutionBook_Environment] CHECK ([EnvironmentType] IN ('BACKTEST', 'MIGRATION_SHADOW', 'FORWARD_PAPER', 'LIVE_MANUAL')),
        CONSTRAINT [CK_TradingSignal_ExecutionBook_StateMetadataJson] CHECK ([StateMetadataJson] IS NULL OR (ISJSON([StateMetadataJson]) = 1 AND DATALENGTH([StateMetadataJson]) <= 2097152)),
        CONSTRAINT [CK_TradingSignal_ExecutionBook_ExposureFactor] CHECK ([ExposureFactor] >= 0)
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[StrategyInstrumentRole]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[StrategyInstrumentRole]
    (
        [StrategyInstrumentRoleID] bigint IDENTITY(1,1) NOT NULL,
        [StrategyDeploymentID]     bigint NOT NULL,
        [InstrumentCode]           varchar(50) NOT NULL,
        [MarketCode]               varchar(50) NULL,
        [InstrumentKind]           varchar(30) NOT NULL,
        [RoleCode]                 varchar(30) NOT NULL,
        [SourceMetadataJson]       nvarchar(max) NULL,
        [CreatedUtc]               datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_StrategyInstrumentRole_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_TradingSignal_StrategyInstrumentRole] PRIMARY KEY CLUSTERED ([StrategyInstrumentRoleID]),
        CONSTRAINT [FK_TradingSignal_StrategyInstrumentRole_Deployment] FOREIGN KEY ([StrategyDeploymentID]) REFERENCES [TradingSignal].[StrategyDeployment] ([StrategyDeploymentID]),
        CONSTRAINT [UQ_TradingSignal_StrategyInstrumentRole_DeploymentRoleInstrument] UNIQUE ([StrategyDeploymentID], [RoleCode], [InstrumentCode]),
        CONSTRAINT [CK_TradingSignal_StrategyInstrumentRole_Role] CHECK ([RoleCode] IN ('SUBJECT', 'SOURCE', 'PROXY', 'EXECUTION', 'BENCHMARK')),
        CONSTRAINT [CK_TradingSignal_StrategyInstrumentRole_SourceMetadataJson] CHECK ([SourceMetadataJson] IS NULL OR (ISJSON([SourceMetadataJson]) = 1 AND DATALENGTH([SourceMetadataJson]) <= 2097152))
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[StrategySchedule]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[StrategySchedule]
    (
        [StrategyScheduleID]   bigint IDENTITY(1,1) NOT NULL,
        [StrategyDeploymentID] bigint NOT NULL,
        [ScheduleKey]          varchar(100) NOT NULL,
        [RunKind]              varchar(30) NOT NULL,
        [TimeZoneName]         varchar(100) NOT NULL CONSTRAINT [DF_TradingSignal_StrategySchedule_TimeZoneName] DEFAULT ('America/New_York'),
        [SessionOffset]        int NULL,
        [LocalTime]            time(0) NULL,
        [CadenceSeconds]       int NULL,
        [DueWindowSeconds]     int NOT NULL,
        [CatchUpPolicy]        varchar(30) NOT NULL,
        [ScheduleJson]         nvarchar(max) NULL,
        [IsEnabled]            bit NOT NULL CONSTRAINT [DF_TradingSignal_StrategySchedule_IsEnabled] DEFAULT ((1)),
        [CreatedUtc]           datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_StrategySchedule_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_TradingSignal_StrategySchedule] PRIMARY KEY CLUSTERED ([StrategyScheduleID]),
        CONSTRAINT [FK_TradingSignal_StrategySchedule_Deployment] FOREIGN KEY ([StrategyDeploymentID]) REFERENCES [TradingSignal].[StrategyDeployment] ([StrategyDeploymentID]),
        CONSTRAINT [UQ_TradingSignal_StrategySchedule_ScheduleKey] UNIQUE ([ScheduleKey]),
        CONSTRAINT [CK_TradingSignal_StrategySchedule_RunKind] CHECK ([RunKind] IN ('DATA_CHECK', 'EVALUATE', 'MONITOR', 'SUMMARY')),
        CONSTRAINT [CK_TradingSignal_StrategySchedule_DueWindow] CHECK ([DueWindowSeconds] >= 0),
        CONSTRAINT [CK_TradingSignal_StrategySchedule_Cadence] CHECK ([CadenceSeconds] IS NULL OR [CadenceSeconds] > 0),
        CONSTRAINT [CK_TradingSignal_StrategySchedule_CatchUpPolicy] CHECK ([CatchUpPolicy] IN ('NONE', 'WITHIN_WINDOW', 'NEXT_SESSION', 'RETRY_SAME_RUN')),
        CONSTRAINT [CK_TradingSignal_StrategySchedule_ScheduleJson] CHECK ([ScheduleJson] IS NULL OR (ISJSON([ScheduleJson]) = 1 AND DATALENGTH([ScheduleJson]) <= 2097152))
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[StrategyRun]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[StrategyRun]
    (
        [StrategyRunID]          uniqueidentifier NOT NULL CONSTRAINT [DF_TradingSignal_StrategyRun_ID] DEFAULT (NEWSEQUENTIALID()),
        [StrategyDeploymentID]   bigint NOT NULL,
        [RunKind]                varchar(30) NOT NULL,
        [ScheduledEffectiveUtc]  datetime2(3) NOT NULL,
        [MarketDate]             date NOT NULL,
        [CorrectionNo]           int NOT NULL CONSTRAINT [DF_TradingSignal_StrategyRun_CorrectionNo] DEFAULT ((0)),
        [IdempotencyKey]         nvarchar(500) NOT NULL,
        [Status]                 varchar(30) NOT NULL CONSTRAINT [DF_TradingSignal_StrategyRun_Status] DEFAULT ('PENDING'),
        [LeaseOwner]             nvarchar(100) NULL,
        [FencingToken]           bigint NOT NULL CONSTRAINT [DF_TradingSignal_StrategyRun_FencingToken] DEFAULT ((0)),
        [LeaseExpiresUtc]        datetime2(3) NULL,
        [NextAttemptUtc]         datetime2(3) NULL,
        [ErrorCode]              varchar(100) NULL,
        [ErrorMessage]           nvarchar(2000) NULL,
        [GitCommit]              varchar(100) NULL,
        [ConfigurationHash]      char(64) NULL,
        [DataHash]               char(64) NULL,
        [CreatedUtc]             datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_StrategyRun_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        [StartedUtc]             datetime2(3) NULL,
        [CompletedUtc]           datetime2(3) NULL,
        [RowVersion]             rowversion NOT NULL,
        CONSTRAINT [PK_TradingSignal_StrategyRun] PRIMARY KEY CLUSTERED ([StrategyRunID]),
        CONSTRAINT [FK_TradingSignal_StrategyRun_Deployment] FOREIGN KEY ([StrategyDeploymentID]) REFERENCES [TradingSignal].[StrategyDeployment] ([StrategyDeploymentID]),
        CONSTRAINT [UQ_TradingSignal_StrategyRun_IdempotencyKey] UNIQUE ([IdempotencyKey]),
        CONSTRAINT [UQ_TradingSignal_StrategyRun_ScheduledIdentity] UNIQUE ([StrategyDeploymentID], [RunKind], [ScheduledEffectiveUtc], [CorrectionNo]),
        CONSTRAINT [CK_TradingSignal_StrategyRun_RunKind] CHECK ([RunKind] IN ('DATA_CHECK', 'EVALUATE', 'MONITOR', 'SUMMARY')),
        CONSTRAINT [CK_TradingSignal_StrategyRun_CorrectionNo] CHECK ([CorrectionNo] >= 0),
        CONSTRAINT [CK_TradingSignal_StrategyRun_Status] CHECK ([Status] IN ('PENDING', 'CLAIMED', 'SUCCEEDED', 'RETRY_WAITING', 'FAILED_TERMINAL')),
        CONSTRAINT [CK_TradingSignal_StrategyRun_ConfigurationHash] CHECK ([ConfigurationHash] IS NULL OR LEN([ConfigurationHash]) = 64),
        CONSTRAINT [CK_TradingSignal_StrategyRun_DataHash] CHECK ([DataHash] IS NULL OR LEN([DataHash]) = 64)
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[StrategyRunAttempt]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[StrategyRunAttempt]
    (
        [StrategyRunAttemptID] bigint IDENTITY(1,1) NOT NULL,
        [StrategyRunID]        uniqueidentifier NOT NULL,
        [AttemptNo]            int NOT NULL,
        [WorkerID]             nvarchar(100) NOT NULL,
        [FencingToken]         bigint NOT NULL,
        [StartedUtc]           datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_StrategyRunAttempt_StartedUtc] DEFAULT (SYSUTCDATETIME()),
        [CompletedUtc]         datetime2(3) NULL,
        [Outcome]              varchar(30) NULL,
        [RetryClassification]  varchar(30) NULL,
        [ErrorCode]            varchar(100) NULL,
        [ErrorMessage]         nvarchar(2000) NULL,
        [DependencyTimingJson] nvarchar(max) NULL,
        CONSTRAINT [PK_TradingSignal_StrategyRunAttempt] PRIMARY KEY CLUSTERED ([StrategyRunAttemptID]),
        CONSTRAINT [FK_TradingSignal_StrategyRunAttempt_Run] FOREIGN KEY ([StrategyRunID]) REFERENCES [TradingSignal].[StrategyRun] ([StrategyRunID]),
        CONSTRAINT [UQ_TradingSignal_StrategyRunAttempt_RunAttempt] UNIQUE ([StrategyRunID], [AttemptNo]),
        CONSTRAINT [CK_TradingSignal_StrategyRunAttempt_DependencyTimingJson] CHECK ([DependencyTimingJson] IS NULL OR (ISJSON([DependencyTimingJson]) = 1 AND DATALENGTH([DependencyTimingJson]) <= 2097152))
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[Observation]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[Observation]
    (
        [ObservationID]         bigint IDENTITY(1,1) NOT NULL,
        [StrategyDeploymentID]  bigint NOT NULL,
        [MarketDate]            date NOT NULL,
        [RevisionNo]            int NOT NULL CONSTRAINT [DF_TradingSignal_Observation_RevisionNo] DEFAULT ((0)),
        [PreviousObservationDate] date NULL,
        [QualityStatus]         varchar(20) NOT NULL,
        [QualityIssuesJson]     nvarchar(max) NULL,
        [FactsJson]             nvarchar(max) NOT NULL,
        [SourceManifestJson]    nvarchar(max) NOT NULL,
        [DataHash]              char(64) NOT NULL,
        [CreatedUtc]            datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_Observation_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_TradingSignal_Observation] PRIMARY KEY CLUSTERED ([ObservationID]),
        CONSTRAINT [FK_TradingSignal_Observation_Deployment] FOREIGN KEY ([StrategyDeploymentID]) REFERENCES [TradingSignal].[StrategyDeployment] ([StrategyDeploymentID]),
        CONSTRAINT [UQ_TradingSignal_Observation_DeploymentDateRevision] UNIQUE ([StrategyDeploymentID], [MarketDate], [RevisionNo]),
        CONSTRAINT [UQ_TradingSignal_Observation_DeploymentDateHash] UNIQUE ([StrategyDeploymentID], [MarketDate], [DataHash]),
        CONSTRAINT [CK_TradingSignal_Observation_RevisionNo] CHECK ([RevisionNo] >= 0),
        CONSTRAINT [CK_TradingSignal_Observation_QualityStatus] CHECK ([QualityStatus] IN ('VALID', 'WARNING', 'BLOCKED')),
        CONSTRAINT [CK_TradingSignal_Observation_QualityIssuesJson] CHECK ([QualityIssuesJson] IS NULL OR (ISJSON([QualityIssuesJson]) = 1 AND DATALENGTH([QualityIssuesJson]) <= 2097152)),
        CONSTRAINT [CK_TradingSignal_Observation_FactsJson] CHECK (ISJSON([FactsJson]) = 1 AND DATALENGTH([FactsJson]) <= 2097152),
        CONSTRAINT [CK_TradingSignal_Observation_SourceManifestJson] CHECK (ISJSON([SourceManifestJson]) = 1 AND DATALENGTH([SourceManifestJson]) <= 2097152),
        CONSTRAINT [CK_TradingSignal_Observation_DataHash] CHECK (LEN([DataHash]) = 64)
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[Signal]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[Signal]
    (
        [SignalID]             bigint IDENTITY(1,1) NOT NULL,
        [ObservationID]        bigint NOT NULL,
        [StrategyVersionID]    bigint NOT NULL,
        [Classification]       varchar(150) NOT NULL,
        [Direction]            varchar(20) NOT NULL,
        [Confidence]           varchar(30) NOT NULL,
        [ActionCode]           varchar(30) NOT NULL,
        [DetectionUtc]         datetime2(3) NOT NULL,
        [ActionableUtc]        datetime2(3) NULL,
        [HoldingPeriodCode]    varchar(30) NULL,
        [MetricsJson]          nvarchar(max) NOT NULL,
        [ResearchMetadataJson] nvarchar(max) NULL,
        [CreatedUtc]           datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_Signal_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_TradingSignal_Signal] PRIMARY KEY CLUSTERED ([SignalID]),
        CONSTRAINT [FK_TradingSignal_Signal_Observation] FOREIGN KEY ([ObservationID]) REFERENCES [TradingSignal].[Observation] ([ObservationID]),
        CONSTRAINT [FK_TradingSignal_Signal_Version] FOREIGN KEY ([StrategyVersionID]) REFERENCES [TradingSignal].[StrategyVersion] ([StrategyVersionID]),
        CONSTRAINT [UQ_TradingSignal_Signal_ObservationVersionClassification] UNIQUE ([ObservationID], [StrategyVersionID], [Classification]),
        CONSTRAINT [CK_TradingSignal_Signal_Direction] CHECK ([Direction] IN ('LONG', 'SHORT', 'NONE')),
        CONSTRAINT [CK_TradingSignal_Signal_Confidence] CHECK ([Confidence] IN ('NONE', 'LOW', 'LOW_MEDIUM', 'MEDIUM', 'MEDIUM_HIGH', 'HIGH')),
        CONSTRAINT [CK_TradingSignal_Signal_Action] CHECK ([ActionCode] IN ('NONE', 'WATCH', 'PLAN_ENTRY')),
        CONSTRAINT [CK_TradingSignal_Signal_MetricsJson] CHECK (ISJSON([MetricsJson]) = 1 AND DATALENGTH([MetricsJson]) <= 2097152),
        CONSTRAINT [CK_TradingSignal_Signal_ResearchMetadataJson] CHECK ([ResearchMetadataJson] IS NULL OR (ISJSON([ResearchMetadataJson]) = 1 AND DATALENGTH([ResearchMetadataJson]) <= 2097152)),
        CONSTRAINT [CK_TradingSignal_Signal_NoneDirection] CHECK ([Direction] <> 'NONE' OR [ActionCode] <> 'PLAN_ENTRY')
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[StrategyComparison]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[StrategyComparison]
    (
        [StrategyComparisonID]       bigint IDENTITY(1,1) NOT NULL,
        [ObservationID]              bigint NOT NULL,
        [PrimarySignalID]            bigint NULL,
        [ComparisonSignalID]         bigint NULL,
        [PrimaryStrategyVersionID]   bigint NOT NULL,
        [ComparisonStrategyVersionID] bigint NOT NULL,
        [EnvironmentType]            varchar(30) NOT NULL,
        [OutcomeStatus]              varchar(30) NOT NULL,
        [OutcomeJson]                nvarchar(max) NOT NULL,
        [MetricsJson]                nvarchar(max) NULL,
        [CreatedUtc]                 datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_StrategyComparison_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_TradingSignal_StrategyComparison] PRIMARY KEY CLUSTERED ([StrategyComparisonID]),
        CONSTRAINT [FK_TradingSignal_StrategyComparison_Observation] FOREIGN KEY ([ObservationID]) REFERENCES [TradingSignal].[Observation] ([ObservationID]),
        CONSTRAINT [FK_TradingSignal_StrategyComparison_PrimarySignal] FOREIGN KEY ([PrimarySignalID]) REFERENCES [TradingSignal].[Signal] ([SignalID]),
        CONSTRAINT [FK_TradingSignal_StrategyComparison_ComparisonSignal] FOREIGN KEY ([ComparisonSignalID]) REFERENCES [TradingSignal].[Signal] ([SignalID]),
        CONSTRAINT [FK_TradingSignal_StrategyComparison_PrimaryVersion] FOREIGN KEY ([PrimaryStrategyVersionID]) REFERENCES [TradingSignal].[StrategyVersion] ([StrategyVersionID]),
        CONSTRAINT [FK_TradingSignal_StrategyComparison_ComparisonVersion] FOREIGN KEY ([ComparisonStrategyVersionID]) REFERENCES [TradingSignal].[StrategyVersion] ([StrategyVersionID]),
        CONSTRAINT [UQ_TradingSignal_StrategyComparison_Identity] UNIQUE ([ObservationID], [PrimaryStrategyVersionID], [ComparisonStrategyVersionID], [EnvironmentType]),
        CONSTRAINT [CK_TradingSignal_StrategyComparison_Environment] CHECK ([EnvironmentType] IN ('BACKTEST', 'MIGRATION_SHADOW', 'FORWARD_PAPER', 'LIVE_MANUAL')),
        CONSTRAINT [CK_TradingSignal_StrategyComparison_OutcomeJson] CHECK (ISJSON([OutcomeJson]) = 1 AND DATALENGTH([OutcomeJson]) <= 2097152),
        CONSTRAINT [CK_TradingSignal_StrategyComparison_MetricsJson] CHECK ([MetricsJson] IS NULL OR (ISJSON([MetricsJson]) = 1 AND DATALENGTH([MetricsJson]) <= 2097152))
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[SignalOutcome]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[SignalOutcome]
    (
        [SignalOutcomeID]          bigint IDENTITY(1,1) NOT NULL,
        [SignalID]                 bigint NOT NULL,
        [HorizonCode]             varchar(20) NOT NULL,
        [RevisionNo]              int NOT NULL CONSTRAINT [DF_TradingSignal_SignalOutcome_RevisionNo] DEFAULT ((0)),
        [ReferencePrice]           decimal(19,8) NULL,
        [ReferenceUtc]             datetime2(3) NULL,
        [HorizonMarketDate]        date NULL,
        [HorizonClose]             decimal(19,8) NULL,
        [RawReturnPct]             decimal(19,8) NULL,
        [DirectionalReturnPct]     decimal(19,8) NULL,
        [MaximumFavorablePct]      decimal(19,8) NULL,
        [MaximumAdversePct]        decimal(19,8) NULL,
        [NullReason]               varchar(100) NULL,
        [SourceManifestJson]       nvarchar(max) NOT NULL,
        [DataHash]                 char(64) NOT NULL,
        [FinalizedUtc]             datetime2(3) NULL,
        [SupersedesSignalOutcomeID] bigint NULL,
        CONSTRAINT [PK_TradingSignal_SignalOutcome] PRIMARY KEY CLUSTERED ([SignalOutcomeID]),
        CONSTRAINT [FK_TradingSignal_SignalOutcome_Signal] FOREIGN KEY ([SignalID]) REFERENCES [TradingSignal].[Signal] ([SignalID]),
        CONSTRAINT [FK_TradingSignal_SignalOutcome_Supersedes] FOREIGN KEY ([SupersedesSignalOutcomeID]) REFERENCES [TradingSignal].[SignalOutcome] ([SignalOutcomeID]),
        CONSTRAINT [UQ_TradingSignal_SignalOutcome_SignalHorizonRevision] UNIQUE ([SignalID], [HorizonCode], [RevisionNo]),
        CONSTRAINT [UQ_TradingSignal_SignalOutcome_SignalHorizonHash] UNIQUE ([SignalID], [HorizonCode], [DataHash]),
        CONSTRAINT [CK_TradingSignal_SignalOutcome_RevisionNo] CHECK ([RevisionNo] >= 0),
        CONSTRAINT [CK_TradingSignal_SignalOutcome_SourceManifestJson] CHECK (ISJSON([SourceManifestJson]) = 1 AND DATALENGTH([SourceManifestJson]) <= 2097152),
        CONSTRAINT [CK_TradingSignal_SignalOutcome_DataHash] CHECK (LEN([DataHash]) = 64),
        CONSTRAINT [CK_TradingSignal_SignalOutcome_NoSelfSupersede] CHECK ([SupersedesSignalOutcomeID] IS NULL OR [SupersedesSignalOutcomeID] <> [SignalOutcomeID])
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[TradePlan]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[TradePlan]
    (
        [TradePlanID]             bigint IDENTITY(1,1) NOT NULL,
        [SignalID]                bigint NOT NULL,
        [ExecutionBookID]         bigint NOT NULL,
        [ExecutionInstrumentCode] varchar(50) NOT NULL,
        [Direction]               varchar(20) NOT NULL,
        [PlanStatus]              varchar(30) NOT NULL,
        [PlannedEntryUtc]         datetime2(3) NOT NULL,
        [PlannedExitUtc]          datetime2(3) NULL,
        [ActualEntryUtc]          datetime2(3) NULL,
        [ActualEntryPrice]        decimal(19,8) NULL,
        [ActualExitUtc]           datetime2(3) NULL,
        [ActualExitPrice]         decimal(19,8) NULL,
        [TakeProfitPrice]         decimal(19,8) NULL,
        [StopLossPrice]           decimal(19,8) NULL,
        [Quantity]                decimal(19,8) NOT NULL CONSTRAINT [DF_TradingSignal_TradePlan_Quantity] DEFAULT ((1)),
        [ExitReason]              varchar(30) NULL,
        [OccupancyKey]            nvarchar(200) NULL,
        [MetadataJson]            nvarchar(max) NOT NULL,
        [CreatedUtc]              datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_TradePlan_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        [RowVersion]              rowversion NOT NULL,
        CONSTRAINT [PK_TradingSignal_TradePlan] PRIMARY KEY CLUSTERED ([TradePlanID]),
        CONSTRAINT [FK_TradingSignal_TradePlan_Signal] FOREIGN KEY ([SignalID]) REFERENCES [TradingSignal].[Signal] ([SignalID]),
        CONSTRAINT [FK_TradingSignal_TradePlan_ExecutionBook] FOREIGN KEY ([ExecutionBookID]) REFERENCES [TradingSignal].[ExecutionBook] ([ExecutionBookID]),
        CONSTRAINT [UQ_TradingSignal_TradePlan_SignalBook] UNIQUE ([SignalID], [ExecutionBookID]),
        CONSTRAINT [CK_TradingSignal_TradePlan_Direction] CHECK ([Direction] IN ('LONG', 'SHORT')),
        CONSTRAINT [CK_TradingSignal_TradePlan_Status] CHECK ([PlanStatus] IN ('WAITING_ENTRY', 'ACTIVE', 'EXITED_TP', 'EXITED_SL', 'EXITED_TIME', 'CANCELLED')),
        CONSTRAINT [CK_TradingSignal_TradePlan_Quantity] CHECK ([Quantity] > 0),
        CONSTRAINT [CK_TradingSignal_TradePlan_ExitReason] CHECK ([ExitReason] IS NULL OR [ExitReason] IN ('TP', 'SL', 'TIME', 'CANCELLED', 'DATA_ERROR', 'OPERATOR')),
        CONSTRAINT [CK_TradingSignal_TradePlan_MetadataJson] CHECK (ISJSON([MetadataJson]) = 1 AND DATALENGTH([MetadataJson]) <= 2097152),
        CONSTRAINT [CK_TradingSignal_TradePlan_Occupancy] CHECK (([PlanStatus] IN ('WAITING_ENTRY', 'ACTIVE') AND [OccupancyKey] IS NOT NULL) OR ([PlanStatus] NOT IN ('WAITING_ENTRY', 'ACTIVE') AND [OccupancyKey] IS NULL))
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[TradePlanEvent]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[TradePlanEvent]
    (
        [TradePlanEventID] bigint IDENTITY(1,1) NOT NULL,
        [TradePlanID]       bigint NOT NULL,
        [StrategyRunID]     uniqueidentifier NOT NULL,
        [EventType]         varchar(30) NOT NULL,
        [EffectiveUtc]      datetime2(3) NOT NULL,
        [Price]             decimal(19,8) NULL,
        [ReasonCode]        varchar(100) NULL,
        [PayloadJson]       nvarchar(max) NULL,
        [IdempotencyKey]    nvarchar(500) NOT NULL,
        [CreatedUtc]        datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_TradePlanEvent_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_TradingSignal_TradePlanEvent] PRIMARY KEY CLUSTERED ([TradePlanEventID]),
        CONSTRAINT [FK_TradingSignal_TradePlanEvent_Plan] FOREIGN KEY ([TradePlanID]) REFERENCES [TradingSignal].[TradePlan] ([TradePlanID]),
        CONSTRAINT [FK_TradingSignal_TradePlanEvent_Run] FOREIGN KEY ([StrategyRunID]) REFERENCES [TradingSignal].[StrategyRun] ([StrategyRunID]),
        CONSTRAINT [UQ_TradingSignal_TradePlanEvent_IdempotencyKey] UNIQUE ([IdempotencyKey]),
        CONSTRAINT [CK_TradingSignal_TradePlanEvent_Type] CHECK ([EventType] IN ('PLANNED', 'ENTERED', 'EXITED_TP', 'EXITED_SL', 'EXITED_TIME', 'CANCELLED', 'EXIT_APPROACHING', 'OPPOSING_SIGNAL')),
        CONSTRAINT [CK_TradingSignal_TradePlanEvent_PayloadJson] CHECK ([PayloadJson] IS NULL OR (ISJSON([PayloadJson]) = 1 AND DATALENGTH([PayloadJson]) <= 2097152))
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[ReportSnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[ReportSnapshot]
    (
        [ReportSnapshotID]       bigint IDENTITY(1,1) NOT NULL,
        [StrategyRunID]          uniqueidentifier NOT NULL,
        [SignalID]               bigint NULL,
        [TradePlanID]            bigint NULL,
        [PublicReportID]         uniqueidentifier NOT NULL CONSTRAINT [DF_TradingSignal_ReportSnapshot_PublicReportID] DEFAULT (NEWSEQUENTIALID()),
        [ReportKind]             varchar(100) NOT NULL,
        [ReportDate]             date NOT NULL,
        [ObservationDate]        date NULL,
        [StrategyCode]           varchar(100) NOT NULL,
        [StrategyVersionCode]    varchar(100) NOT NULL,
        [DeploymentKey]          varchar(200) NOT NULL,
        [EnvironmentType]        varchar(30) NOT NULL,
        [SubjectInstrumentCode]  varchar(50) NULL,
        [ExecutionInstrumentCode] varchar(50) NULL,
        [Title]                  nvarchar(300) NOT NULL,
        [Summary]                nvarchar(2000) NULL,
        [FileName]               nvarchar(260) NULL,
        [RevisionNo]             int NOT NULL CONSTRAINT [DF_TradingSignal_ReportSnapshot_RevisionNo] DEFAULT ((0)),
        [ContentHash]            char(64) NOT NULL,
        [HtmlContent]            nvarchar(max) NOT NULL,
        [GeneratedUtc]           datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_ReportSnapshot_GeneratedUtc] DEFAULT (SYSUTCDATETIME()),
        [SupersedesReportID]     bigint NULL,
        CONSTRAINT [PK_TradingSignal_ReportSnapshot] PRIMARY KEY CLUSTERED ([ReportSnapshotID]),
        CONSTRAINT [FK_TradingSignal_ReportSnapshot_Run] FOREIGN KEY ([StrategyRunID]) REFERENCES [TradingSignal].[StrategyRun] ([StrategyRunID]),
        CONSTRAINT [FK_TradingSignal_ReportSnapshot_Signal] FOREIGN KEY ([SignalID]) REFERENCES [TradingSignal].[Signal] ([SignalID]),
        CONSTRAINT [FK_TradingSignal_ReportSnapshot_TradePlan] FOREIGN KEY ([TradePlanID]) REFERENCES [TradingSignal].[TradePlan] ([TradePlanID]),
        CONSTRAINT [FK_TradingSignal_ReportSnapshot_Supersedes] FOREIGN KEY ([SupersedesReportID]) REFERENCES [TradingSignal].[ReportSnapshot] ([ReportSnapshotID]),
        CONSTRAINT [UQ_TradingSignal_ReportSnapshot_RunKind] UNIQUE ([StrategyRunID], [ReportKind]),
        CONSTRAINT [UQ_TradingSignal_ReportSnapshot_PublicReportID] UNIQUE ([PublicReportID]),
        CONSTRAINT [CK_TradingSignal_ReportSnapshot_Environment] CHECK ([EnvironmentType] IN ('BACKTEST', 'MIGRATION_SHADOW', 'FORWARD_PAPER', 'LIVE_MANUAL')),
        CONSTRAINT [CK_TradingSignal_ReportSnapshot_RevisionNo] CHECK ([RevisionNo] >= 0),
        CONSTRAINT [CK_TradingSignal_ReportSnapshot_ContentHash] CHECK (LEN([ContentHash]) = 64),
        CONSTRAINT [CK_TradingSignal_ReportSnapshot_HtmlSize] CHECK (DATALENGTH([HtmlContent]) <= 10485760),
        CONSTRAINT [CK_TradingSignal_ReportSnapshot_NoSelfSupersede] CHECK ([SupersedesReportID] IS NULL OR [SupersedesReportID] <> [ReportSnapshotID])
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[NotificationEvent]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[NotificationEvent]
    (
        [NotificationEventID]       bigint IDENTITY(1,1) NOT NULL,
        [NotificationEventPublicID] uniqueidentifier NOT NULL CONSTRAINT [DF_TradingSignal_NotificationEvent_PublicID] DEFAULT (NEWSEQUENTIALID()),
        [SignalID]                  bigint NULL,
        [TradePlanEventID]          bigint NULL,
        [ReportSnapshotID]          bigint NULL,
        [NotificationType]          varchar(50) NOT NULL,
        [RecipientKey]              nvarchar(200) NOT NULL,
        [TargetUserID]              int NULL,
        [TargetRole]                varchar(50) NULL,
        [ChannelCode]               varchar(30) NOT NULL,
        [Title]                     nvarchar(255) NOT NULL,
        [Body]                      nvarchar(max) NOT NULL,
        [Priority]                  int NOT NULL CONSTRAINT [DF_TradingSignal_NotificationEvent_Priority] DEFAULT ((0)),
        [TemplateVersion]           varchar(50) NOT NULL,
        [IdempotencyKey]            nvarchar(500) NOT NULL,
        [RequiresDelivery]          bit NOT NULL CONSTRAINT [DF_TradingSignal_NotificationEvent_RequiresDelivery] DEFAULT ((1)),
        [MetadataJson]              nvarchar(max) NULL,
        [CreatedUtc]                datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_NotificationEvent_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_TradingSignal_NotificationEvent] PRIMARY KEY CLUSTERED ([NotificationEventID]),
        CONSTRAINT [FK_TradingSignal_NotificationEvent_Signal] FOREIGN KEY ([SignalID]) REFERENCES [TradingSignal].[Signal] ([SignalID]),
        CONSTRAINT [FK_TradingSignal_NotificationEvent_TradePlanEvent] FOREIGN KEY ([TradePlanEventID]) REFERENCES [TradingSignal].[TradePlanEvent] ([TradePlanEventID]),
        CONSTRAINT [FK_TradingSignal_NotificationEvent_Report] FOREIGN KEY ([ReportSnapshotID]) REFERENCES [TradingSignal].[ReportSnapshot] ([ReportSnapshotID]),
        CONSTRAINT [UQ_TradingSignal_NotificationEvent_PublicID] UNIQUE ([NotificationEventPublicID]),
        CONSTRAINT [UQ_TradingSignal_NotificationEvent_IdempotencyKey] UNIQUE ([IdempotencyKey]),
        CONSTRAINT [CK_TradingSignal_NotificationEvent_ReportRequired] CHECK ([RequiresDelivery] = 0 OR [ReportSnapshotID] IS NOT NULL),
        CONSTRAINT [CK_TradingSignal_NotificationEvent_MetadataJson] CHECK ([MetadataJson] IS NULL OR (ISJSON([MetadataJson]) = 1 AND DATALENGTH([MetadataJson]) <= 2097152))
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[NotificationDelivery]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[NotificationDelivery]
    (
        [NotificationDeliveryID] bigint IDENTITY(1,1) NOT NULL,
        [NotificationEventID]    bigint NOT NULL,
        [ChannelCode]            varchar(30) NOT NULL,
        [RecipientKey]           nvarchar(200) NOT NULL,
        [QueueMessageID]         bigint NULL,
        [State]                  varchar(30) NOT NULL CONSTRAINT [DF_TradingSignal_NotificationDelivery_State] DEFAULT ('PENDING'),
        [AttemptCount]           int NOT NULL CONSTRAINT [DF_TradingSignal_NotificationDelivery_AttemptCount] DEFAULT ((0)),
        [LeaseOwner]             nvarchar(100) NULL,
        [LeaseExpiresUtc]        datetime2(3) NULL,
        [ProviderRequestID]      nvarchar(200) NULL,
        [LastError]              nvarchar(2000) NULL,
        [CreatedUtc]             datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_NotificationDelivery_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        [LastUpdatedUtc]         datetime2(3) NULL,
        [RowVersion]             rowversion NOT NULL,
        CONSTRAINT [PK_TradingSignal_NotificationDelivery] PRIMARY KEY CLUSTERED ([NotificationDeliveryID]),
        CONSTRAINT [FK_TradingSignal_NotificationDelivery_Event] FOREIGN KEY ([NotificationEventID]) REFERENCES [TradingSignal].[NotificationEvent] ([NotificationEventID]),
        CONSTRAINT [UQ_TradingSignal_NotificationDelivery_EventChannelRecipient] UNIQUE ([NotificationEventID], [ChannelCode], [RecipientKey]),
        CONSTRAINT [CK_TradingSignal_NotificationDelivery_State] CHECK ([State] IN ('PENDING', 'QUEUED', 'PROCESSING', 'SENT', 'RETRY_WAITING', 'FAILED', 'DELIVERY_UNKNOWN', 'SKIPPED'))
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[AuditEvent]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[AuditEvent]
    (
        [AuditEventID]      bigint IDENTITY(1,1) NOT NULL,
        [EventType]         varchar(100) NOT NULL,
        [Source]            varchar(100) NOT NULL,
        [PayloadJson]       nvarchar(max) NOT NULL,
        [LegacyIdentity]    nvarchar(500) NULL,
        [CreatedUtc]        datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_AuditEvent_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_TradingSignal_AuditEvent] PRIMARY KEY CLUSTERED ([AuditEventID]),
        CONSTRAINT [CK_TradingSignal_AuditEvent_PayloadJson] CHECK (ISJSON([PayloadJson]) = 1 AND DATALENGTH([PayloadJson]) <= 2097152)
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[LegacyImportBatch]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[LegacyImportBatch]
    (
        [ImportBatchID]          uniqueidentifier NOT NULL CONSTRAINT [DF_TradingSignal_LegacyImportBatch_ID] DEFAULT (NEWSEQUENTIALID()),
        [SourceSystem]           varchar(100) NOT NULL,
        [SourcePath]             nvarchar(1000) NULL,
        [SourceFileHash]         char(64) NOT NULL,
        [SourceSchemaFingerprint] char(64) NULL,
        [ImportToolVersion]      varchar(100) NOT NULL,
        [Status]                 varchar(30) NOT NULL,
        [CountSummaryJson]       nvarchar(max) NULL,
        [ErrorSummaryJson]       nvarchar(max) NULL,
        [StartedUtc]             datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_LegacyImportBatch_StartedUtc] DEFAULT (SYSUTCDATETIME()),
        [CompletedUtc]          datetime2(3) NULL,
        CONSTRAINT [PK_TradingSignal_LegacyImportBatch] PRIMARY KEY CLUSTERED ([ImportBatchID]),
        CONSTRAINT [UQ_TradingSignal_LegacyImportBatch_SourceHash] UNIQUE ([SourceSystem], [SourceFileHash]),
        CONSTRAINT [CK_TradingSignal_LegacyImportBatch_Status] CHECK ([Status] IN ('STARTED', 'DRY_RUN', 'COMPLETED', 'FAILED', 'VERIFIED')),
        CONSTRAINT [CK_TradingSignal_LegacyImportBatch_CountSummaryJson] CHECK ([CountSummaryJson] IS NULL OR (ISJSON([CountSummaryJson]) = 1 AND DATALENGTH([CountSummaryJson]) <= 2097152)),
        CONSTRAINT [CK_TradingSignal_LegacyImportBatch_ErrorSummaryJson] CHECK ([ErrorSummaryJson] IS NULL OR (ISJSON([ErrorSummaryJson]) = 1 AND DATALENGTH([ErrorSummaryJson]) <= 2097152)),
        CONSTRAINT [CK_TradingSignal_LegacyImportBatch_SourceFileHash] CHECK (LEN([SourceFileHash]) = 64)
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[LegacyIdentityMap]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[LegacyIdentityMap]
    (
        [LegacyIdentityMapID] bigint IDENTITY(1,1) NOT NULL,
        [ImportBatchID]        uniqueidentifier NOT NULL,
        [SourceSystem]        varchar(100) NOT NULL,
        [SourceTable]         varchar(128) NOT NULL,
        [LegacyID]            nvarchar(200) NOT NULL,
        [TargetEntityType]    varchar(100) NOT NULL,
        [TargetEntityID]      nvarchar(100) NOT NULL,
        [MappingMetadataJson] nvarchar(max) NULL,
        [CreatedUtc]          datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_LegacyIdentityMap_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_TradingSignal_LegacyIdentityMap] PRIMARY KEY CLUSTERED ([LegacyIdentityMapID]),
        CONSTRAINT [FK_TradingSignal_LegacyIdentityMap_Batch] FOREIGN KEY ([ImportBatchID]) REFERENCES [TradingSignal].[LegacyImportBatch] ([ImportBatchID]),
        CONSTRAINT [UQ_TradingSignal_LegacyIdentityMap_SourceIdentity] UNIQUE ([SourceSystem], [SourceTable], [LegacyID]),
        CONSTRAINT [UQ_TradingSignal_LegacyIdentityMap_TargetIdentity] UNIQUE ([TargetEntityType], [TargetEntityID]),
        CONSTRAINT [CK_TradingSignal_LegacyIdentityMap_MappingMetadataJson] CHECK ([MappingMetadataJson] IS NULL OR (ISJSON([MappingMetadataJson]) = 1 AND DATALENGTH([MappingMetadataJson]) <= 2097152))
    );
END;
GO

IF OBJECT_ID(N'[TradingSignal].[ReportAlias]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[ReportAlias]
    (
        [ReportAliasID]       bigint IDENTITY(1,1) NOT NULL,
        [AliasKey]            nvarchar(500) NOT NULL,
        [LegacyFileName]      nvarchar(260) NULL,
        [LegacyPath]          nvarchar(1000) NULL,
        [LegacyReportDate]    date NULL,
        [EnvironmentType]     varchar(30) NULL,
        [ReportSnapshotID]    bigint NOT NULL,
        [ImportBatchID]       uniqueidentifier NULL,
        [CreatedUtc]          datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_ReportAlias_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_TradingSignal_ReportAlias] PRIMARY KEY CLUSTERED ([ReportAliasID]),
        CONSTRAINT [FK_TradingSignal_ReportAlias_Report] FOREIGN KEY ([ReportSnapshotID]) REFERENCES [TradingSignal].[ReportSnapshot] ([ReportSnapshotID]),
        CONSTRAINT [FK_TradingSignal_ReportAlias_Batch] FOREIGN KEY ([ImportBatchID]) REFERENCES [TradingSignal].[LegacyImportBatch] ([ImportBatchID]),
        CONSTRAINT [UQ_TradingSignal_ReportAlias_AliasKey] UNIQUE ([AliasKey]),
        CONSTRAINT [CK_TradingSignal_ReportAlias_Environment] CHECK ([EnvironmentType] IS NULL OR [EnvironmentType] IN ('BACKTEST', 'MIGRATION_SHADOW', 'FORWARD_PAPER', 'LIVE_MANUAL'))
    );
END;
GO

/* Supporting non-unique indexes. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE [name] = N'IX_TradingSignal_StrategyRun_Due' AND [object_id] = OBJECT_ID(N'[TradingSignal].[StrategyRun]'))
    CREATE INDEX [IX_TradingSignal_StrategyRun_Due] ON [TradingSignal].[StrategyRun] ([Status], [NextAttemptUtc], [ScheduledEffectiveUtc]) INCLUDE ([StrategyDeploymentID], [RunKind], [MarketDate], [LeaseExpiresUtc]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE [name] = N'IX_TradingSignal_Observation_DeploymentDate' AND [object_id] = OBJECT_ID(N'[TradingSignal].[Observation]'))
    CREATE INDEX [IX_TradingSignal_Observation_DeploymentDate] ON [TradingSignal].[Observation] ([StrategyDeploymentID], [MarketDate] DESC, [RevisionNo] DESC) INCLUDE ([QualityStatus], [DataHash]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE [name] = N'IX_TradingSignal_Signal_Observation' AND [object_id] = OBJECT_ID(N'[TradingSignal].[Signal]'))
    CREATE INDEX [IX_TradingSignal_Signal_Observation] ON [TradingSignal].[Signal] ([ObservationID]) INCLUDE ([StrategyVersionID], [Classification], [Direction], [ActionCode]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE [name] = N'IX_TradingSignal_TradePlan_Open' AND [object_id] = OBJECT_ID(N'[TradingSignal].[TradePlan]'))
    CREATE INDEX [IX_TradingSignal_TradePlan_Open] ON [TradingSignal].[TradePlan] ([ExecutionBookID], [PlanStatus], [PlannedEntryUtc]) INCLUDE ([SignalID], [OccupancyKey], [ActualEntryUtc]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE [name] = N'UX_TradingSignal_TradePlan_Occupancy' AND [object_id] = OBJECT_ID(N'[TradingSignal].[TradePlan]'))
    CREATE UNIQUE INDEX [UX_TradingSignal_TradePlan_Occupancy] ON [TradingSignal].[TradePlan] ([ExecutionBookID], [OccupancyKey]) WHERE [OccupancyKey] IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE [name] = N'IX_TradingSignal_ReportSnapshot_Catalog' AND [object_id] = OBJECT_ID(N'[TradingSignal].[ReportSnapshot]'))
    CREATE INDEX [IX_TradingSignal_ReportSnapshot_Catalog] ON [TradingSignal].[ReportSnapshot] ([StrategyCode], [EnvironmentType], [ReportDate] DESC, [GeneratedUtc] DESC, [PublicReportID]) INCLUDE ([ReportKind], [StrategyVersionCode], [SubjectInstrumentCode], [ExecutionInstrumentCode], [RevisionNo], [SupersedesReportID], [Title], [Summary]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE [name] = N'IX_TradingSignal_NotificationDelivery_State' AND [object_id] = OBJECT_ID(N'[TradingSignal].[NotificationDelivery]'))
    CREATE INDEX [IX_TradingSignal_NotificationDelivery_State] ON [TradingSignal].[NotificationDelivery] ([State], [LeaseExpiresUtc], [LastUpdatedUtc]) INCLUDE ([NotificationEventID], [QueueMessageID], [AttemptCount]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE [name] = N'IX_TradingSignal_AuditEvent_CreatedUtc' AND [object_id] = OBJECT_ID(N'[TradingSignal].[AuditEvent]'))
    CREATE INDEX [IX_TradingSignal_AuditEvent_CreatedUtc] ON [TradingSignal].[AuditEvent] ([CreatedUtc] DESC, [EventType]);
GO
