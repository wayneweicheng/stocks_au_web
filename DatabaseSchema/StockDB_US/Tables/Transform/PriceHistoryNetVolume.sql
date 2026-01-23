-- Table: [Transform].[PriceHistoryNetVolume]

CREATE TABLE [Transform].[PriceHistoryNetVolume] (
    [PriceHistoryNetVolume] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [NetVolume] [bigint] NULL,
    [NetValue] [decimal](20,4) NULL,
    [TotalVolume] [bigint] NULL,
    [TotalValue] [decimal](20,4) NULL,
    [CreateDate] [smalldatetime] NULL
);
