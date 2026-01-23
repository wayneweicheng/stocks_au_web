-- Table: [BackTest].[Strategy]

CREATE TABLE [BackTest].[Strategy] (
    [StrategyID] [smallint] IDENTITY(1,1) NOT NULL,
    [StrategyName] [varchar](100) NOT NULL,
    [StrategyDescription] [varchar](MAX) NOT NULL,
    [MaxHoldDays] [int] NULL,
    [AlertTypeID] [tinyint] NOT NULL,
    [IsDisabled] [bit] NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_backteststrategy_strategyid] PRIMARY KEY (StrategyID)
);
