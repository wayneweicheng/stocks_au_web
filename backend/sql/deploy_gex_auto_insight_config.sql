-- Deploy GEX Auto Insight Configuration
-- Run this script against StockDB_US database

USE [StockDB_US]
GO

-- Create Configuration schema if not exists
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Configuration')
BEGIN
    EXEC('CREATE SCHEMA [Configuration]')
    PRINT 'Created schema [Configuration]'
END
GO

-- Create the configuration table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[Configuration].[GEXAutoInsightStocks]') AND type in (N'U'))
BEGIN
    CREATE TABLE [Configuration].[GEXAutoInsightStocks] (
        [StockCode] [varchar](20) NOT NULL,
        [DisplayName] [nvarchar](100) NULL,
        [IsActive] [bit] NOT NULL DEFAULT ((1)),
        [Priority] [int] NOT NULL DEFAULT ((0)),
        [LLMModel] [varchar](100) NULL,
        [CreatedDate] [datetime] NOT NULL DEFAULT (getdate()),
        [UpdatedDate] [datetime] NOT NULL DEFAULT (getdate()),
        CONSTRAINT [PK_Configuration_GEXAutoInsightStocks] PRIMARY KEY (StockCode)
    );
    PRINT 'Created table [Configuration].[GEXAutoInsightStocks]'
END
GO

-- Create index
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_GEXAutoInsightStocks_IsActive' AND object_id = OBJECT_ID('[Configuration].[GEXAutoInsightStocks]'))
BEGIN
    CREATE INDEX [IX_GEXAutoInsightStocks_IsActive]
    ON [Configuration].[GEXAutoInsightStocks] (IsActive, Priority DESC);
    PRINT 'Created index IX_GEXAutoInsightStocks_IsActive'
END
GO

-- Create stored procedure: usp_GetGEXAutoInsightStocks
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[Configuration].[usp_GetGEXAutoInsightStocks]') AND type in (N'P'))
    DROP PROCEDURE [Configuration].[usp_GetGEXAutoInsightStocks]
GO

CREATE PROCEDURE [Configuration].[usp_GetGEXAutoInsightStocks]
    @pbitActiveOnly BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        StockCode,
        DisplayName,
        IsActive,
        Priority,
        LLMModel,
        CreatedDate,
        UpdatedDate
    FROM [Configuration].[GEXAutoInsightStocks]
    WHERE @pbitActiveOnly = 0 OR IsActive = 1
    ORDER BY Priority DESC, StockCode ASC;
END
GO
PRINT 'Created procedure [Configuration].[usp_GetGEXAutoInsightStocks]'
GO

-- Create stored procedure: usp_UpsertGEXAutoInsightStock
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[Configuration].[usp_UpsertGEXAutoInsightStock]') AND type in (N'P'))
    DROP PROCEDURE [Configuration].[usp_UpsertGEXAutoInsightStock]
GO

CREATE PROCEDURE [Configuration].[usp_UpsertGEXAutoInsightStock]
    @pvchStockCode VARCHAR(20),
    @pnvcDisplayName NVARCHAR(100) = NULL,
    @pbitIsActive BIT = 1,
    @pintPriority INT = 0,
    @pvchLLMModel VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    MERGE INTO [Configuration].[GEXAutoInsightStocks] AS target
    USING (SELECT @pvchStockCode AS StockCode) AS source
    ON target.StockCode = source.StockCode
    WHEN MATCHED THEN
        UPDATE SET
            DisplayName = ISNULL(@pnvcDisplayName, target.DisplayName),
            IsActive = @pbitIsActive,
            Priority = @pintPriority,
            LLMModel = @pvchLLMModel,
            UpdatedDate = GETDATE()
    WHEN NOT MATCHED THEN
        INSERT (StockCode, DisplayName, IsActive, Priority, LLMModel)
        VALUES (@pvchStockCode, @pnvcDisplayName, @pbitIsActive, @pintPriority, @pvchLLMModel);

    SELECT
        StockCode,
        DisplayName,
        IsActive,
        Priority,
        LLMModel,
        CreatedDate,
        UpdatedDate
    FROM [Configuration].[GEXAutoInsightStocks]
    WHERE StockCode = @pvchStockCode;
END
GO
PRINT 'Created procedure [Configuration].[usp_UpsertGEXAutoInsightStock]'
GO

-- Create stored procedure: usp_DeleteGEXAutoInsightStock
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[Configuration].[usp_DeleteGEXAutoInsightStock]') AND type in (N'P'))
    DROP PROCEDURE [Configuration].[usp_DeleteGEXAutoInsightStock]
GO

CREATE PROCEDURE [Configuration].[usp_DeleteGEXAutoInsightStock]
    @pvchStockCode VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM [Configuration].[GEXAutoInsightStocks]
    WHERE StockCode = @pvchStockCode;

    SELECT @@ROWCOUNT AS RowsDeleted;
END
GO
PRINT 'Created procedure [Configuration].[usp_DeleteGEXAutoInsightStock]'
GO

-- Seed initial stocks (only if table is empty)
IF NOT EXISTS (SELECT 1 FROM [Configuration].[GEXAutoInsightStocks])
BEGIN
    INSERT INTO [Configuration].[GEXAutoInsightStocks] (StockCode, DisplayName, Priority, IsActive)
    VALUES
        ('SPXW.US', 'S&P 500 Weekly Options', 100, 1),
        ('SPY.US', 'S&P 500 ETF', 95, 1),
        ('QQQ.US', 'Nasdaq 100 ETF', 90, 1),
        ('NVDA.US', 'NVIDIA', 85, 1),
        ('META.US', 'Meta Platforms', 80, 1),
        ('TSLA.US', 'Tesla', 75, 1),
        ('GDX.US', 'Gold Miners ETF', 70, 1),
        ('SLV.US', 'Silver ETF', 65, 1),
        ('AVGO.US', 'Broadcom', 60, 1);

    PRINT 'Seeded initial stocks'
END
GO

PRINT 'GEX Auto Insight Configuration deployment complete'
GO
