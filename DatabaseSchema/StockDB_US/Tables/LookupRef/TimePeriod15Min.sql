-- Table: [LookupRef].[TimePeriod15Min]

CREATE TABLE [LookupRef].[TimePeriod15Min] (
    [TimePeriod15MinID] [int] IDENTITY(1,1) NOT NULL,
    [TimeStart] [smalldatetime] NOT NULL,
    [TimeEnd] [smalldatetime] NOT NULL,
    [TimeLabel] [varchar](200) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_lookupreftimeperiod15min_timeperiod15minid] PRIMARY KEY (TimePeriod15MinID)
);
