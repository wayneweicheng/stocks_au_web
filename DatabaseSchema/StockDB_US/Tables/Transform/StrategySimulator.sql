-- Table: [Transform].[StrategySimulator]

CREATE TABLE [Transform].[StrategySimulator] (
    [StrategySimulatorID] [int] IDENTITY(1,1) NOT NULL,
    [StrategyID] [int] NOT NULL,
    [UniqueKey] [int] NOT NULL,
    [Underlying] [varchar](10) NULL,
    [CumulativeGain] [decimal](20,4) NULL,
    [TomorrowOpenToCloseChange] [decimal](10,2) NULL,
    [TomorrowChange] [decimal](10,2) NULL,
    [SwingIndicator] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [ASXCode] [varchar](10) NULL,
    [Close] [decimal](20,4) NULL,
    [Open] [decimal](20,4) NULL,
    [CreateDate] [smalldatetime] NULL
);
