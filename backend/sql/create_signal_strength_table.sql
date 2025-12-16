-- Signal Strength Classification Table
-- Stores LLM-generated signal strength classifications for stocks
-- Updated whenever price predictions are generated or regenerated

-- Create in Analysis schema to match other GEX tables
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

-- Index for querying by observation date (for the matrix display)
CREATE INDEX IX_SignalStrength_ObservationDate ON Analysis.SignalStrength(ObservationDate);

-- Index for querying by stock code
CREATE INDEX IX_SignalStrength_StockCode ON Analysis.SignalStrength(StockCode);

-- Comment for documentation
EXEC sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Stores signal strength classification from LLM price predictions. Updated when predictions are generated or regenerated.',
    @level0type = N'SCHEMA', @level0name = N'Analysis',
    @level1type = N'TABLE',  @level1name = N'SignalStrength';
