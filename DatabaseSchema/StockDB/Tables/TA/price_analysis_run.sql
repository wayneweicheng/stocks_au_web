-- Table: [TA].[price_analysis_run]

CREATE TABLE [TA].[price_analysis_run] (
    [run_id] [bigint] IDENTITY(1,1) NOT NULL,
    [run_type] [varchar](32) NOT NULL,
    [symbol] [varchar](32) NULL,
    [as_of_date] [date] NULL,
    [started_at] [datetime2] NOT NULL DEFAULT (sysutcdatetime()),
    [finished_at] [datetime2] NULL,
    [status] [varchar](16) NOT NULL,
    [code_version] [varchar](64) NULL,
    [notes] [varchar](1000) NULL
,
    CONSTRAINT [PK__price_an__7D3D901B025CE887] PRIMARY KEY (run_id)
);
