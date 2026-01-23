-- Table: [dbo].[flyway_schema_history]

CREATE TABLE [dbo].[flyway_schema_history] (
    [installed_rank] [int] NOT NULL,
    [version] [nvarchar](50) NULL,
    [description] [nvarchar](200) NULL,
    [type] [nvarchar](20) NOT NULL,
    [script] [nvarchar](1000) NOT NULL,
    [checksum] [int] NULL,
    [installed_by] [nvarchar](100) NOT NULL,
    [installed_on] [datetime] NOT NULL DEFAULT (getdate()),
    [execution_time] [int] NOT NULL,
    [success] [bit] NOT NULL
,
    CONSTRAINT [flyway_schema_history_pk] PRIMARY KEY (installed_rank)
);

CREATE INDEX [flyway_schema_history_s_idx] ON [dbo].[flyway_schema_history] (success);