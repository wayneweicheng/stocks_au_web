-- Table: [Transform].[CHIXVolumeAndVWAP]

CREATE TABLE [Transform].[CHIXVolumeAndVWAP] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [varchar](50) NULL,
    [Close] [decimal](20,4) NOT NULL,
    [TotalVWAP] [decimal](20,4) NULL,
    [ChiXvwap] [decimal](38,6) NULL,
    [ASXVWAP] [decimal](38,6) NULL,
    [TotalVolume] [nvarchar](4000) NULL,
    [ASXVolume] [nvarchar](4000) NULL,
    [TotalValue] [nvarchar](4000) NULL,
    [ASXValue] [nvarchar](4000) NULL,
    [PriceChangeVsPrevClose] [decimal](20,4) NULL,
    [PriceChangeVsOpen] [decimal](10,2) NULL,
    [CHIXPerc] [decimal](10,2) NULL,
    [AvgCHIXPerc] [decimal](38,6) NULL,
    [AnnDescr] [varchar](200) NULL
);
