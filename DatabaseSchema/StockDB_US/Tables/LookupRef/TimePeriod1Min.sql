-- Table: [LookupRef].[TimePeriod1Min]

CREATE TABLE [LookupRef].[TimePeriod1Min] (
    [TimePeriod1MinID] [int] IDENTITY(1,1) NOT NULL,
    [TimeStart] [smalldatetime] NOT NULL,
    [TimeEnd] [smalldatetime] NOT NULL,
    [TimeLabel] [varchar](200) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_lookupreftimeperiod1min_timeperiod1minid] PRIMARY KEY (TimePeriod1MinID)
);
