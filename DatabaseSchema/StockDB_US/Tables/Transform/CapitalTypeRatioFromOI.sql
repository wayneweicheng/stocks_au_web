-- Table: [Transform].[CapitalTypeRatioFromOI]

CREATE TABLE [Transform].[CapitalTypeRatioFromOI] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NULL,
    [CapitalType] [varchar](12) NULL,
    [GEX] [decimal](38,4) NULL,
    [AggPerc] [decimal](10,2) NULL,
    [CreateDate] [smalldatetime] NULL
);
