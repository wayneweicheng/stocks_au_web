-- Migration: Add SourceType column to SignalStrength table
-- This allows us to distinguish between GEX-based signals and Breakout Analysis signals

-- Step 1: Add the SourceType column (nullable initially)
ALTER TABLE Analysis.SignalStrength
ADD SourceType VARCHAR(20) NULL;

-- Step 2: Set default value for existing rows (assume they're from GEX analysis)
UPDATE Analysis.SignalStrength
SET SourceType = 'GEX'
WHERE SourceType IS NULL;

-- Step 3: Make the column NOT NULL with a default
ALTER TABLE Analysis.SignalStrength
ALTER COLUMN SourceType VARCHAR(20) NOT NULL;

-- Step 4: Add constraint to validate source types
ALTER TABLE Analysis.SignalStrength
ADD CONSTRAINT CK_SignalStrength_SourceType CHECK (SourceType IN ('GEX', 'BREAKOUT'));

-- Step 5: Drop the old primary key
ALTER TABLE Analysis.SignalStrength
DROP CONSTRAINT PK_SignalStrength;

-- Step 6: Create new composite primary key including SourceType
ALTER TABLE Analysis.SignalStrength
ADD CONSTRAINT PK_SignalStrength PRIMARY KEY (ObservationDate, StockCode, SourceType);

-- Step 7: Update indexes
DROP INDEX IX_SignalStrength_ObservationDate ON Analysis.SignalStrength;
DROP INDEX IX_SignalStrength_StockCode ON Analysis.SignalStrength;

-- Create new composite indexes
CREATE INDEX IX_SignalStrength_ObservationDate_SourceType ON Analysis.SignalStrength(ObservationDate, SourceType);
CREATE INDEX IX_SignalStrength_StockCode_SourceType ON Analysis.SignalStrength(StockCode, SourceType);

-- Add column description
EXEC sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Source of the signal: GEX (Market Flow Signals) or BREAKOUT (Breakout Consolidation Analysis)',
    @level0type = N'SCHEMA', @level0name = N'Analysis',
    @level1type = N'TABLE',  @level1name = N'SignalStrength',
    @level2type = N'COLUMN', @level2name = N'SourceType';

PRINT 'Successfully added SourceType column to SignalStrength table';
