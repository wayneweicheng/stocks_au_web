-- Table: [Report].[SectorPerformanceDetails]

CREATE TABLE [Report].[SectorPerformanceDetails] (
    [Token] [varchar](200) NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [close] [decimal](20,4) NOT NULL,
    [Volume] [bigint] NOT NULL,
    [TradeValue] [decimal](38,4) NULL,
    [NumStockInSector] [int] NULL,
    [IsFirstDay] [bit] NULL,
    [HoldQuantity] [int] NULL,
    [HoldValue] [decimal](20,5) NULL,
    [ReferenceOBDate] [date] NULL,
    [PeriodStartDate] [date] NULL,
    [DateSeqNo] [bigint] NULL,
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL
,
    CONSTRAINT [pk_report_sectorperformancedetails_uniquekey] PRIMARY KEY (UniqueKey)
);
