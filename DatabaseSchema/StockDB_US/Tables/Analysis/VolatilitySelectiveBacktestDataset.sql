IF OBJECT_ID(N'[Analysis].[VolatilitySelectiveBacktestDataset]', N'U') IS NULL
BEGIN
    CREATE TABLE [Analysis].[VolatilitySelectiveBacktestDataset] (
        [DatasetId] bigint IDENTITY(1,1) NOT NULL,
        [RunId] nvarchar(100) NOT NULL,
        [DatasetName] nvarchar(300) NULL,
        [StartDate] date NULL,
        [EndDate] date NULL,
        [Source] nvarchar(500) NULL,
        [DatasetJson] nvarchar(max) NOT NULL,
        [CreatedAt] datetime2(0) NOT NULL CONSTRAINT [DF_VSODataset_CreatedAt] DEFAULT (getutcdate()),
        CONSTRAINT [PK_VolatilitySelectiveBacktestDataset] PRIMARY KEY CLUSTERED ([DatasetId]),
        CONSTRAINT [UQ_VolatilitySelectiveBacktestDataset_RunId] UNIQUE ([RunId])
    );
END;
GO
