-- Table: [BackTest].[StrategyExecution]

CREATE TABLE [BackTest].[StrategyExecution] (
    [StrategyExecutionID] [int] IDENTITY(1,1) NOT NULL,
    [ExecutionID] [int] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [EntryPrice] [decimal](20,4) NOT NULL,
    [ActualBuyPrice] [decimal](20,4) NULL,
    [ActualBuyDateTime] [datetime] NOT NULL,
    [ExitPrice] [decimal](20,4) NOT NULL,
    [StopLossPrice] [decimal](20,4) NOT NULL,
    [ActualSellPrice] [decimal](20,4) NULL,
    [ActualSellDateTime] [datetime] NULL,
    [Volume] [bigint] NOT NULL,
    [BuyTotalValue] [decimal](20,4) NULL,
    [SellTotalValue] [decimal](20,4) NULL,
    [BrokerageFee] [decimal](20,4) NULL,
    [ActualHoldDays] [int] NULL,
    [ProfitLost] [decimal](20,4) NULL,
    [CreateDate] [smalldatetime] NULL,
    [ObservationDayPriceIncreasePerc] [decimal](5,2) NULL,
    [ExitRuleID] [int] NULL
);
