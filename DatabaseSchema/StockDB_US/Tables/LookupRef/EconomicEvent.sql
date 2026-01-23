-- Table: [LookupRef].[EconomicEvent]

CREATE TABLE [LookupRef].[EconomicEvent] (
    [EconomicEventID] [int] IDENTITY(1,1) NOT NULL,
    [Id] [varchar](50) NULL,
    [AUTime] [datetime] NULL,
    [USTime] [datetime] NULL,
    [EventName] [varchar](250) NULL,
    [Impact] [varchar](50) NULL,
    [Currency] [varchar](50) NULL,
    [CreateDate] [smalldatetime] NULL
);
