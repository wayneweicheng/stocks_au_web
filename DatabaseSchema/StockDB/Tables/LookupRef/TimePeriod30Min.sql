-- Table: [LookupRef].[TimePeriod30Min]

CREATE TABLE [LookupRef].[TimePeriod30Min] (
    [TimePeriod30MinID] [int] IDENTITY(1,1) NOT NULL,
    [TimeStart] [smalldatetime] NOT NULL,
    [TimeEnd] [smalldatetime] NOT NULL,
    [TimeLabel] [varchar](200) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_lookupreftimeperiod30min_timeperiod30minid] PRIMARY KEY (TimePeriod30MinID)
);
