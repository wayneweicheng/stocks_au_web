-- Table: [Transform].[OptionGEXChangeCapitalType]

CREATE TABLE [Transform].[OptionGEXChangeCapitalType] (
    [ObservationDate] [date] NULL,
    [ASXCode] [varchar](10) NULL,
    [GEXDelta] [int] NULL,
    [CapitalType] [varchar](10) NULL,
    [Close] [decimal](20,4) NULL,
    [VWAP] [decimal](20,4) NULL,
    [NoOfOption] [bigint] NULL,
    [GEX] [bigint] NULL
);

CREATE INDEX [idx_transformoptiongexchangecapitaltype_asxcodeobdatecapitaltypeIncgexdelta] ON [Transform].[OptionGEXChangeCapitalType] (GEXDelta, ASXCode, ObservationDate, CapitalType);