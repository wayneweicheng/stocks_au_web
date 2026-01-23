-- Table: [LookupRef].[TimePeriod5Min]

CREATE TABLE [LookupRef].[TimePeriod5Min] (
    [TimePeriod5MinID] [int] IDENTITY(1,1) NOT NULL,
    [TimeStart] [smalldatetime] NOT NULL,
    [TimeEnd] [smalldatetime] NOT NULL,
    [TimeLabel] [varchar](200) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_lookupreftimeperiod5min_timeperiod5minid] PRIMARY KEY (TimePeriod5MinID)
);
