-- Table: [Research].[ASXDataRefreshStage]

CREATE TABLE [Research].[ASXDataRefreshStage] (
    [StageID] [int] IDENTITY(1,1) NOT NULL,
    [JobID] [int] NOT NULL,
    [StageKey] [varchar](50) NOT NULL,
    [StageLabel] [varchar](100) NOT NULL,
    [Status] [varchar](20) NOT NULL DEFAULT ('pending'),
    [StartedAt] [datetime2] NULL,
    [CompletedAt] [datetime2] NULL,
    [Detail] [nvarchar](MAX) NULL,
    [Output] [nvarchar](MAX) NULL,
    [SortOrder] [int] NOT NULL
,
    CONSTRAINT [PK_ASXDataRefreshStage] PRIMARY KEY (StageID)
);

ALTER TABLE [Research].[ASXDataRefreshStage] ADD CONSTRAINT [FK_ASXDataRefreshStage_Job] FOREIGN KEY (JobID) REFERENCES [Research].[ASXDataRefreshJob] (JobID);
CREATE UNIQUE INDEX [IX_ASXDataRefreshStage_Job_StageKey] ON [Research].[ASXDataRefreshStage] (JobID, StageKey);