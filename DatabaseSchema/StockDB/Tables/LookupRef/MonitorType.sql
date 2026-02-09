-- Table: [LookupRef].[MonitorType]

CREATE TABLE [LookupRef].[MonitorType] (
    [MonitorTypeID] [varchar](20) NOT NULL,
    [MonitorTypeDescr] [varchar](200) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_lookuprefmonitortpype_monitortypeid] PRIMARY KEY (MonitorTypeID)
);
