-- Table: [BackTest].[ExecutionSettingStock]

CREATE TABLE [BackTest].[ExecutionSettingStock] (
    [ExecutionSettingStockID] [int] IDENTITY(1,1) NOT NULL,
    [ExecutionSettingID] [smallint] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [IsDisabled] [bit] NULL,
    [CreateDate] [smalldatetime] NULL
);
