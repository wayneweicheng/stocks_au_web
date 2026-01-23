-- Table: [Transform].[SmartDumbCapitalTypeRatioByHour]

CREATE TABLE [Transform].[SmartDumbCapitalTypeRatioByHour] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NULL,
    [TradeHour] [datetime] NULL,
    [CapitalType] [varchar](12) NULL,
    [DumbGEX] [decimal](38,4) NULL,
    [DumbAggPerc] [decimal](10,2) NULL,
    [SmartGEX] [decimal](38,4) NULL,
    [SmartAggPerc] [decimal](10,2) NULL,
    [SmartDumbAggPercRatio] [numeric](26,14) NULL,
    [CreateDate] [smalldatetime] NULL
);
