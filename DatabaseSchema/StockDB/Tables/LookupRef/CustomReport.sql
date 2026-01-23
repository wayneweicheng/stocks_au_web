-- Table: [LookupRef].[CustomReport]

CREATE TABLE [LookupRef].[CustomReport] (
    [CustomReportID] [int] IDENTITY(1,1) NOT NULL,
    [ReportName] [varchar](200) NULL,
    [ReportDescription] [varchar](200) NULL,
    [ReportScore] [decimal](10,1) NULL,
    [CreateDate] [smalldatetime] NULL
);
