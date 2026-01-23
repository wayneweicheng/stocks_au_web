-- Table: [StockData].[FinraDIX]

CREATE TABLE [StockData].[FinraDIX] (
    [FinraDIXID] [int] IDENTITY(1,1) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [Symbol] [varchar](20) NOT NULL,
    [ShortVolume] [bigint] NULL,
    [ShortExemptVolume] [bigint] NULL,
    [TotalVolume] [bigint] NULL,
    [Market] [varchar](50) NULL,
    [CreateDate] [smalldatetime] NULL
);
