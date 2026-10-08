/* Reference/event inputs for fail-closed volatility-selective scans.
   Populate confirmed earnings, dividend, corporate, macro, or other binary-event
   windows before enabling scheduled scans for single stocks. */
IF OBJECT_ID(N'[Analysis].[VolatilitySelectiveEvent]', N'U') IS NULL
BEGIN
    CREATE TABLE [Analysis].[VolatilitySelectiveEvent] (
        [EventId] bigint IDENTITY(1,1) NOT NULL,
        [Symbol] nvarchar(20) NOT NULL,
        [EventType] nvarchar(50) NOT NULL,
        [EventDate] date NOT NULL,
        [EventEndDate] date NULL,
        [Status] nvarchar(20) NOT NULL CONSTRAINT [DF_VSOEvent_Status] DEFAULT ('CONFIRMED'),
        [Source] nvarchar(500) NULL,
        [Notes] nvarchar(2000) NULL,
        [CreatedAt] datetime2(0) NOT NULL CONSTRAINT [DF_VSOEvent_CreatedAt] DEFAULT (getutcdate()),
        [UpdatedAt] datetime2(0) NOT NULL CONSTRAINT [DF_VSOEvent_UpdatedAt] DEFAULT (getutcdate()),
        CONSTRAINT [PK_VolatilitySelectiveEvent] PRIMARY KEY CLUSTERED ([EventId]),
        CONSTRAINT [CK_VSOEvent_Status] CHECK ([Status] IN ('CONFIRMED', 'CANCELLED', 'UNKNOWN'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_VSOEvent_SymbolDate' AND object_id = OBJECT_ID(N'[Analysis].[VolatilitySelectiveEvent]'))
    CREATE INDEX [IX_VSOEvent_SymbolDate] ON [Analysis].[VolatilitySelectiveEvent] ([Symbol], [EventDate], [Status]);
GO
