-- Table: [Transform].[EquityPutCallRatio]

CREATE TABLE [Transform].[EquityPutCallRatio] (
    [ObservationDate] [date] NULL,
    [ASXCode] [varchar](10) NULL,
    [IOrO] [varchar](7) NOT NULL,
    [LongExpiry] [int] NOT NULL,
    [PCRVolume] [numeric](38,6) NULL,
    [PCROI] [numeric](38,6) NULL,
    [Close] [decimal](20,4) NULL
);
