-- Table: [Transform].[OptionGEXChangeCapitalType_Pre]

CREATE TABLE [Transform].[OptionGEXChangeCapitalType_Pre] (
    [ObservationDate] [date] NULL,
    [ASXCode] [varchar](10) NULL,
    [GEXDelta] [int] NULL,
    [CapitalType] [varchar](10) NULL,
    [Close] [decimal](20,4) NULL,
    [VWAP] [decimal](20,4) NULL
);
