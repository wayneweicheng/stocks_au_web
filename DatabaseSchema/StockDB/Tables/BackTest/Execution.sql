-- Table: [BackTest].[Execution]

CREATE TABLE [BackTest].[Execution] (
    [ExecutionID] [int] IDENTITY(1,1) NOT NULL,
    [StrategyID] [smallint] NOT NULL,
    [ExecutionSettingID] [smallint] NOT NULL,
    [DateFrom] [date] NOT NULL,
    [DateTo] [date] NOT NULL
);
