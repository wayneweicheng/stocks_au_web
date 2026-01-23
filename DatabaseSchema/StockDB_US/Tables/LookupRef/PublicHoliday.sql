-- Table: [LookupRef].[PublicHoliday]

CREATE TABLE [LookupRef].[PublicHoliday] (
    [PublicHolidayID] [int] IDENTITY(1,1) NOT NULL,
    [HolidayDate] [date] NULL,
    [HolidayName] [varchar](100) NOT NULL,
    [CreateDate] [smalldatetime] NULL
);
