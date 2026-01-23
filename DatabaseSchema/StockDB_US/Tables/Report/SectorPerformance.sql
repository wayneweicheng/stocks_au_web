-- Table: [Report].[SectorPerformance]

CREATE TABLE [Report].[SectorPerformance] (
    [Token] [varchar](200) NULL,
    [ObservationDate] [date] NOT NULL,
    [HoldValue] [decimal](38,5) NULL,
    [TradeValue] [decimal](38,4) NULL,
    [ASXCode] [int] NULL,
    [AvgHoldValue] [numeric](38,6) NULL,
    [MAAvgHoldKey] [varchar](6) NOT NULL,
    [MAAvgHoldValue] [decimal](38,5) NULL
);
