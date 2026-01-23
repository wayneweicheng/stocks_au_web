-- Table: [Alert].[SectorPerformanceAlert]

CREATE TABLE [Alert].[SectorPerformanceAlert] (
    [SectorPerformanceAlertID] [int] IDENTITY(1,1) NOT NULL,
    [Token] [varchar](200) NOT NULL,
    [ObservationDate] [varchar](50) NULL,
    [VSMA5] [decimal](38,5) NULL,
    [VSMA50] [decimal](38,5) NULL,
    [Prev1ObservationDate] [varchar](50) NULL,
    [Prev2ObservationDate] [varchar](50) NULL,
    [Prev3ObservationDate] [varchar](50) NULL,
    [NumStock] [int] NULL,
    [AlertSentDate] [smalldatetime] NULL
,
    CONSTRAINT [pk_report_sectorperformancealertid_sectorperformancealertid] PRIMARY KEY (SectorPerformanceAlertID)
);
