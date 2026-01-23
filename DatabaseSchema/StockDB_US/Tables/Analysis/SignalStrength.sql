-- Table: [Analysis].[SignalStrength]

CREATE TABLE [Analysis].[SignalStrength] (
    [ObservationDate] [date] NOT NULL,
    [StockCode] [varchar](20) NOT NULL,
    [SignalStrengthLevel] [varchar](30) NOT NULL,
    [CreatedAt] [datetime] NOT NULL DEFAULT (getdate()),
    [UpdatedAt] [datetime] NOT NULL DEFAULT (getdate()),
    [SourceType] [varchar](20) NOT NULL
,
    CONSTRAINT [PK_SignalStrength] PRIMARY KEY (ObservationDate, StockCode, SourceType)
);

CREATE INDEX [IX_SignalStrength_ObservationDate_SourceType] ON [Analysis].[SignalStrength] (ObservationDate, SourceType);
CREATE INDEX [IX_SignalStrength_StockCode_SourceType] ON [Analysis].[SignalStrength] (StockCode, SourceType);