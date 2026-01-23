-- Table: [BackTest].[BackTestExecution]

CREATE TABLE [BackTest].[BackTestExecution] (
    [ExecutionId] [uniqueidentifier] NOT NULL,
    [OrderTypeId] [int] NOT NULL,
    [StrategyFileName] [varchar](500) NULL,
    [ExecutionContext] [varchar](MAX) NULL,
    [CreateDate] [smalldatetime] NULL,
    [ASXCode] [varchar](20) NULL
);
