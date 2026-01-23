-- Table: [Transform].[MoneyFlowInfoAgg]

CREATE TABLE [Transform].[MoneyFlowInfoAgg] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NULL,
    [MaxTotalScore] [decimal](20,4) NULL,
    [AvgTotalScore] [decimal](38,6) NULL,
    [MinTotalScore] [decimal](20,4) NULL,
    [MaxNearScore] [decimal](20,4) NULL,
    [AvgNearScore] [decimal](38,6) NULL,
    [MinNearScore] [decimal](20,4) NULL,
    [NumObs] [int] NULL
);
