-- Table: [LookupRef].[TimePeriod1Hour]

CREATE TABLE [LookupRef].[TimePeriod1Hour] (
    [TimePeriod1HourID] [int] IDENTITY(1,1) NOT NULL,
    [TimeStart] [smalldatetime] NOT NULL,
    [TimeEnd] [smalldatetime] NOT NULL,
    [TimeLabel] [varchar](200) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_lookupreftimeperiod1hour_timeperiod1hourid] PRIMARY KEY (TimePeriod1HourID)
);
