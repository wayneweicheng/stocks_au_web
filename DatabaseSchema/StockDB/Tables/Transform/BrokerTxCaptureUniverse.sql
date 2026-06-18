-- Table: [Transform].[BrokerTxCaptureUniverse]

CREATE TABLE [Transform].[BrokerTxCaptureUniverse] (
    [ASXCode] [varchar](10) NOT NULL,
    [CaptureMode] [varchar](20) NOT NULL DEFAULT ('CURATED'),
    [Priority] [smallint] NOT NULL DEFAULT ((100)),
    [IsEnabled] [bit] NOT NULL DEFAULT ((1)),
    [Notes] [varchar](500) NULL,
    [LastEvaluatedDate] [date] NULL,
    [CreatedDate] [datetime2] NOT NULL DEFAULT (sysutcdatetime()),
    [ModifiedDate] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_Transform_BrokerTxCaptureUniverse] PRIMARY KEY (ASXCode)
);
