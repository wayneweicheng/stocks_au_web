-- Table: [Transform].[OptionLastHourAction]

CREATE TABLE [Transform].[OptionLastHourAction] (
    [Underlying] [varchar](10) NOT NULL,
    [ObservationDate] [date] NULL,
    [CapitalType] [varchar](2) NOT NULL,
    [Strike] [decimal](20,4) NULL,
    [Gamma] [int] NULL
);
