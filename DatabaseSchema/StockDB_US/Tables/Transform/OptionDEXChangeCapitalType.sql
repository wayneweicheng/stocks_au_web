-- Table: [Transform].[OptionDEXChangeCapitalType]

CREATE TABLE [Transform].[OptionDEXChangeCapitalType] (
    [ObservationDate] [date] NULL,
    [ASXCode] [varchar](10) NULL,
    [DEXDelta] [int] NULL,
    [CapitalType] [varchar](10) NULL,
    [Close] [decimal](20,4) NULL,
    [VWAP] [decimal](20,4) NULL
);
