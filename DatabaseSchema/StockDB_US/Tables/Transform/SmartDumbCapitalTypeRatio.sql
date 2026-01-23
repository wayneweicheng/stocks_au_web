-- Table: [Transform].[SmartDumbCapitalTypeRatio]

CREATE TABLE [Transform].[SmartDumbCapitalTypeRatio] (
    [SmartDumbCapitalTypeRatioID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NULL,
    [CapitalType] [varchar](12) NULL,
    [DumbGEX] [int] NULL,
    [DumbAggPerc] [decimal](10,2) NULL,
    [SmartGEX] [int] NULL,
    [SmartAggPerc] [decimal](10,2) NULL,
    [SmartDumbAggPercRatio] [numeric](10,2) NULL,
    [CreateDate] [smalldatetime] NOT NULL
);
