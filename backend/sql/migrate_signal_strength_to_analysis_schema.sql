-- Migration script to move SignalStrength table from dbo to Analysis schema
-- Run this if you already created the table in dbo schema

-- Step 1: Check if table exists in dbo schema
IF OBJECT_ID('dbo.SignalStrength', 'U') IS NOT NULL
BEGIN
    PRINT 'Found SignalStrength in dbo schema. Starting migration...'

    -- Step 2: If Analysis.SignalStrength exists, drop it first
    IF OBJECT_ID('Analysis.SignalStrength', 'U') IS NOT NULL
    BEGIN
        PRINT 'Dropping existing Analysis.SignalStrength table...'
        DROP TABLE Analysis.SignalStrength;
    END

    -- Step 3: Create table in Analysis schema
    PRINT 'Creating Analysis.SignalStrength table...'
    CREATE TABLE Analysis.SignalStrength (
        ObservationDate DATE NOT NULL,
        StockCode VARCHAR(20) NOT NULL,
        SignalStrengthLevel VARCHAR(30) NOT NULL CHECK (SignalStrengthLevel IN (
            'STRONGLY_BULLISH',
            'MILDLY_BULLISH',
            'NEUTRAL',
            'MILDLY_BEARISH',
            'STRONGLY_BEARISH'
        )),
        CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
        UpdatedAt DATETIME NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_SignalStrength PRIMARY KEY (ObservationDate, StockCode)
    );

    -- Step 4: Copy data from dbo to Analysis (if any data exists)
    IF EXISTS (SELECT 1 FROM dbo.SignalStrength)
    BEGIN
        PRINT 'Copying data from dbo.SignalStrength to Analysis.SignalStrength...'
        INSERT INTO Analysis.SignalStrength (ObservationDate, StockCode, SignalStrengthLevel, CreatedAt, UpdatedAt)
        SELECT ObservationDate, StockCode, SignalStrengthLevel, CreatedAt, UpdatedAt
        FROM dbo.SignalStrength;

        DECLARE @rowCount INT = @@ROWCOUNT;
        PRINT 'Copied ' + CAST(@rowCount AS VARCHAR) + ' rows.'
    END
    ELSE
    BEGIN
        PRINT 'No data to copy.'
    END

    -- Step 5: Create indexes
    PRINT 'Creating indexes...'
    CREATE INDEX IX_SignalStrength_ObservationDate ON Analysis.SignalStrength(ObservationDate);
    CREATE INDEX IX_SignalStrength_StockCode ON Analysis.SignalStrength(StockCode);

    -- Step 6: Add table comment
    EXEC sp_addextendedproperty
        @name = N'MS_Description',
        @value = N'Stores signal strength classification from LLM price predictions. Updated when predictions are generated or regenerated.',
        @level0type = N'SCHEMA', @level0name = N'Analysis',
        @level1type = N'TABLE',  @level1name = N'SignalStrength';

    -- Step 7: Drop old dbo table
    PRINT 'Dropping old dbo.SignalStrength table...'
    DROP TABLE dbo.SignalStrength;

    PRINT 'Migration completed successfully!'
END
ELSE IF OBJECT_ID('Analysis.SignalStrength', 'U') IS NOT NULL
BEGIN
    PRINT 'Analysis.SignalStrength already exists. No migration needed.'
END
ELSE
BEGIN
    PRINT 'SignalStrength table not found in either schema. Please run create_signal_strength_table.sql instead.'
END
