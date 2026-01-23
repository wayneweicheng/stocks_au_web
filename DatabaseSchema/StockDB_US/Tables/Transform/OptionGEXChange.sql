-- Table: [Transform].[OptionGEXChange]

CREATE TABLE [Transform].[OptionGEXChange] (
    [ObservationDate] [date] NULL,
    [ASXCode] [varchar](10) NULL,
    [GEXDelta] [int] NULL,
    [Close] [decimal](20,4) NULL,
    [VWAP] [decimal](20,4) NULL,
    [NoOfOption] [bigint] NULL,
    [GEX] [bigint] NULL,
    [GEXDeltaAdjusted] [int] NULL
);
