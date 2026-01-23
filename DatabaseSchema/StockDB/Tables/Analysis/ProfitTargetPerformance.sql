-- Table: [Analysis].[ProfitTargetPerformance]

CREATE TABLE [Analysis].[ProfitTargetPerformance] (
    [ID] [int] IDENTITY(1,1) NOT NULL,
    [Stock] [varchar](20) NULL,
    [OrderID] [int] NULL,
    [BuyConditionType] [varchar](50) NULL,
    [EntryTime] [datetime] NULL,
    [EntryPrice] [decimal](12,4) NULL,
    [TargetPrice] [decimal](12,4) NULL,
    [ActualExitPrice] [decimal](12,4) NULL,
    [ProfitTargetPct] [decimal](6,3) NULL,
    [ActualProfitPct] [decimal](6,3) NULL,
    [TargetHit] [bit] NULL,
    [TimeToExit] [int] NULL,
    [CreatedDate] [datetime] NULL DEFAULT (getdate())
,
    CONSTRAINT [PK__ProfitTa__3214EC27F77E0715] PRIMARY KEY (ID)
);

CREATE INDEX [IX_Stock_EntryTime] ON [Analysis].[ProfitTargetPerformance] (Stock, EntryTime);