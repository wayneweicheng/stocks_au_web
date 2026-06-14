-- Table: [StockData].[UnderlyingVolatilityHistory]

CREATE TABLE [StockData].[UnderlyingVolatilityHistory] (
    [ASXCode] [varchar](20) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [IVOpen] [decimal](18,8) NULL,
    [IVHigh] [decimal](18,8) NULL,
    [IVLow] [decimal](18,8) NULL,
    [IVClose] [decimal](18,8) NULL,
    [HVOpen] [decimal](18,8) NULL,
    [HVHigh] [decimal](18,8) NULL,
    [HVLow] [decimal](18,8) NULL,
    [HVClose] [decimal](18,8) NULL,
    [Source] [varchar](30) NOT NULL CONSTRAINT [DF_UnderlyingVolatilityHistory_Source] DEFAULT ('IBKR'),
    [CreateDate] [datetime2](0) NOT NULL CONSTRAINT [DF_UnderlyingVolatilityHistory_CreateDate] DEFAULT (sysdatetime()),
    [ModifyDate] [datetime2](0) NOT NULL CONSTRAINT [DF_UnderlyingVolatilityHistory_ModifyDate] DEFAULT (sysdatetime()),
    CONSTRAINT [PK_UnderlyingVolatilityHistory] PRIMARY KEY CLUSTERED ([ASXCode], [ObservationDate])
);

CREATE INDEX [IX_UnderlyingVolatilityHistory_ObservationDate]
    ON [StockData].[UnderlyingVolatilityHistory] ([ObservationDate], [ASXCode])
    INCLUDE ([IVClose], [HVClose]);
