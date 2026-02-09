-- Table: [Trading].[Strategy]

CREATE TABLE [Trading].[Strategy] (
    [StrategyId] [int] IDENTITY(1,1) NOT NULL,
    [StrategyCode] [varchar](50) NOT NULL,
    [Name] [varchar](100) NOT NULL,
    [Description] [varchar](500) NULL,
    [IsActive] [bit] NOT NULL DEFAULT ((1)),
    [CreatedAt] [datetime] NOT NULL DEFAULT (getdate()),
    [UpdatedAt] [datetime] NOT NULL DEFAULT (getdate())
,
    CONSTRAINT [PK__Strategy__459B986C6D08BEB6] PRIMARY KEY (StrategyId)
);

CREATE UNIQUE INDEX [UQ__Strategy__00D87EE0A9F14CD1] ON [Trading].[Strategy] (StrategyCode);