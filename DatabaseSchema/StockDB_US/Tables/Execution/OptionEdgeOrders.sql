-- Table: [Execution].[OptionEdgeOrders]

CREATE TABLE [Execution].[OptionEdgeOrders] (
    [OrderId] [int] IDENTITY(1,1) NOT NULL,
    [RunId] [nvarchar](100) NOT NULL,
    [RecommendationID] [int] NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [TradingDate] [date] NOT NULL,
    [Ticker] [nvarchar](20) NOT NULL,
    [OptionSymbol] [nvarchar](50) NOT NULL,
    [Underlying] [nvarchar](20) NOT NULL,
    [Strike] [decimal](18,2) NOT NULL,
    [Expiry] [date] NOT NULL,
    [OptionRight] [char](1) NOT NULL,
    [DTE] [int] NOT NULL,
    [Priority] [int] NOT NULL,
    [Rank] [int] NOT NULL,
    [NormalizedRank] [int] NULL,
    [EntryType] [nvarchar](20) NOT NULL DEFAULT ('ENTRY'),
    [EntryLimitPrice] [decimal](18,4) NOT NULL,
    [Quantity] [int] NOT NULL,
    [ComboRegime] [nvarchar](20) NOT NULL,
    [LoosenPct] [decimal](5,2) NOT NULL,
    [IBOrderId] [int] NULL,
    [IBPermId] [int] NULL,
    [Status] [nvarchar](20) NOT NULL DEFAULT ('PENDING'),
    [SubmittedAt] [datetime2] NULL,
    [FilledAt] [datetime2] NULL,
    [FilledPrice] [decimal](18,4) NULL,
    [FilledQty] [int] NULL,
    [CancelledAt] [datetime2] NULL,
    [CancelReason] [nvarchar](200) NULL,
    [ExitOrderPlaced] [bit] NOT NULL DEFAULT ((0)),
    [ExitIBOrderId] [int] NULL,
    [ExitLimitPrice] [decimal](18,4) NULL,
    [ExitFilledAt] [datetime2] NULL,
    [ExitFilledPrice] [decimal](18,4) NULL,
    [ExitFilledQty] [int] NULL,
    [CreatedAt] [datetime2] NOT NULL DEFAULT (getutcdate()),
    [UpdatedAt] [datetime2] NOT NULL DEFAULT (getutcdate())
,
    CONSTRAINT [PK__OptionEd__C3905BCF6B251A8A] PRIMARY KEY (OrderId)
);

CREATE INDEX [IX_OptionEdgeOrders_IBOrderId] ON [Execution].[OptionEdgeOrders] (IBOrderId);
CREATE INDEX [IX_OptionEdgeOrders_OptionSymbol] ON [Execution].[OptionEdgeOrders] (OptionSymbol);
CREATE INDEX [IX_OptionEdgeOrders_RunId] ON [Execution].[OptionEdgeOrders] (RunId);
CREATE INDEX [IX_OptionEdgeOrders_Status] ON [Execution].[OptionEdgeOrders] (Status);
CREATE INDEX [IX_OptionEdgeOrders_TradingDate] ON [Execution].[OptionEdgeOrders] (TradingDate);