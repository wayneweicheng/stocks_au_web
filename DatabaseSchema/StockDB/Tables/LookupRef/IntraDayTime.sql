-- Table: [LookupRef].[IntraDayTime]

CREATE TABLE [LookupRef].[IntraDayTime] (
    [IntraDayTimeID] [int] IDENTITY(1,1) NOT NULL,
    [IntraDayTimeTypeID] [varchar](10) NOT NULL,
    [IntraDayTime] [varchar](5) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_lookuprefintradaytime_intradaytimeid] PRIMARY KEY (IntraDayTimeID)
);
