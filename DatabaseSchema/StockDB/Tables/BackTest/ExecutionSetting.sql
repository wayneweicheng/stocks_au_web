-- Table: [BackTest].[ExecutionSetting]

CREATE TABLE [BackTest].[ExecutionSetting] (
    [ExecutionSettingID] [smallint] IDENTITY(1,1) NOT NULL,
    [ExecutionFilter] [varchar](MAX) NULL,
    [CreateDate] [smalldatetime] NULL,
    [BrokerageFee] [decimal](20,4) NULL,
    [TransactionValue] [decimal](20,4) NULL
);
