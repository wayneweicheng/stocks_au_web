-- Table: [Report].[ReportResultHistory]

CREATE TABLE [Report].[ReportResultHistory] (
    [ReportResultHistoryId] [int] IDENTITY(1,1) NOT NULL,
    [ReportProc] [varchar](200) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NULL,
    [DisplayOrder] [int] NULL,
    [CreateDate] [smalldatetime] NULL
);
