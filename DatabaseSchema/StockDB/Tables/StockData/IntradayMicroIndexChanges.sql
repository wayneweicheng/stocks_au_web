-- Table: [StockData].[IntradayMicroIndexChanges]

CREATE TABLE [StockData].[IntradayMicroIndexChanges] (
    [ObservationDate] [date] NULL,
    [ObservationTime] [time] NULL,
    [VsYesterdayClose_Up] [decimal](10,2) NULL,
    [VsYesterdayClose_Flat] [decimal](10,2) NULL,
    [VsYesterdayClose_Down] [decimal](10,2) NULL,
    [VsOpen_Up] [decimal](10,2) NULL,
    [VsOpen_Flat] [decimal](10,2) NULL,
    [VsOpenDown] [decimal](10,2) NULL,
    [VsVWAP_Up] [decimal](10,2) NULL,
    [VsVWAP_Flat] [decimal](10,2) NULL,
    [VsVWAPDown] [decimal](10,2) NULL,
    [Score] [int] NULL,
    [NumObs] [int] NULL
);
