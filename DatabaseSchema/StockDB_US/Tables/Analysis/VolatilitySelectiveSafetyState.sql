IF OBJECT_ID(N'[Analysis].[VolatilitySelectiveSafetyState]', N'U') IS NULL
BEGIN
    CREATE TABLE [Analysis].[VolatilitySelectiveSafetyState] (
        [StateId] int NOT NULL,
        [KillSwitchActive] bit NOT NULL CONSTRAINT [DF_VSOSafety_KillSwitch] DEFAULT (0),
        [Reason] nvarchar(2000) NULL,
        [UpdatedBy] nvarchar(200) NULL,
        [UpdatedAt] datetime2(0) NOT NULL CONSTRAINT [DF_VSOSafety_UpdatedAt] DEFAULT (getutcdate()),
        CONSTRAINT [PK_VolatilitySelectiveSafetyState] PRIMARY KEY CLUSTERED ([StateId]),
        CONSTRAINT [CK_VSOSafety_Singleton] CHECK ([StateId] = 1)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM [Analysis].[VolatilitySelectiveSafetyState] WHERE [StateId] = 1)
    INSERT INTO [Analysis].[VolatilitySelectiveSafetyState] ([StateId], [KillSwitchActive], [Reason], [UpdatedBy])
    VALUES (1, 0, 'Initial non-executing state', 'DDL');
GO
