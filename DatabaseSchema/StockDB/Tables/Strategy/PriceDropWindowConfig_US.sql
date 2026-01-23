-- Table: [Strategy].[PriceDropWindowConfig_US]

CREATE TABLE [Strategy].[PriceDropWindowConfig_US] (
    [ConfigID] [int] IDENTITY(1,1) NOT NULL,
    [Stock] [nvarchar](32) NOT NULL,
    [DropThresholdPct] [decimal](6,3) NOT NULL,
    [WindowStartET] [time] NOT NULL,
    [WindowEndET] [time] NOT NULL,
    [TargetProfitPct] [decimal](6,3) NOT NULL,
    [BarSizeMinutes] [int] NOT NULL DEFAULT ((5)),
    [IsEnabled] [bit] NOT NULL DEFAULT ((1)),
    [Notes] [nvarchar](200) NULL,
    [UpdatedDate] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK__PriceDro__C3BC333C96876DD2] PRIMARY KEY (ConfigID)
);

CREATE INDEX [IX_PriceDropWindowConfigUS_IsEnabled] ON [Strategy].[PriceDropWindowConfig_US] (IsEnabled);
CREATE UNIQUE INDEX [UX_PriceDropWindowConfigUS_StockWindow] ON [Strategy].[PriceDropWindowConfig_US] (Stock, WindowStartET, WindowEndET, BarSizeMinutes);