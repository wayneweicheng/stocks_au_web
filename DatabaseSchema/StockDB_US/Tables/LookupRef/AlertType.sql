-- Table: [LookupRef].[AlertType]

CREATE TABLE [LookupRef].[AlertType] (
    [AlertTypeID] [tinyint] NOT NULL,
    [AlertTypeName] [varchar](200) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [IsDisabled] [bit] NOT NULL
,
    CONSTRAINT [pk_lookuprefalerttype_alerttypeid] PRIMARY KEY (AlertTypeID)
);
