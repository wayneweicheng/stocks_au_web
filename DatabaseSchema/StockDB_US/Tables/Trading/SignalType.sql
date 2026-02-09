-- Table: [Trading].[SignalType]

CREATE TABLE [Trading].[SignalType] (
    [SignalType] [varchar](50) NOT NULL,
    [Description] [varchar](200) NULL,
    [IsActive] [bit] NOT NULL DEFAULT ((1))
,
    CONSTRAINT [PK__SignalTy__7F656FD13DCBBBCC] PRIMARY KEY (SignalType)
);
