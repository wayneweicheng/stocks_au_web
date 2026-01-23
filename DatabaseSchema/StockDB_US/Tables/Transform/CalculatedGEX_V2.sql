-- Table: [Transform].[CalculatedGEX_V2]

CREATE TABLE [Transform].[CalculatedGEX_V2] (
    [ASXCode] [varchar](10) NULL,
    [ObservationDate] [date] NULL,
    [NoOfOption] [int] NULL,
    [GEX] [numeric](38,6) NULL,
    [FormattedGEX] [nvarchar](4000) NULL,
    [Close] [decimal](20,4) NULL
);
