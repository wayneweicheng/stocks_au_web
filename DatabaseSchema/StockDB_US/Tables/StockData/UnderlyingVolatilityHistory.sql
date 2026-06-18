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
    [Source] [varchar](30) NOT NULL DEFAULT ('IBKR'),
    [CreateDate] [datetime2] NOT NULL DEFAULT (sysdatetime()),
    [ModifyDate] [datetime2] NOT NULL DEFAULT (sysdatetime())
,
    CONSTRAINT [PK_UnderlyingVolatilityHistory] PRIMARY KEY (ASXCode, ObservationDate)
);

CREATE INDEX [IX_UnderlyingVolatilityHistory_ObservationDate] ON [StockData].[UnderlyingVolatilityHistory] (IVClose, HVClose, ObservationDate, ASXCode);