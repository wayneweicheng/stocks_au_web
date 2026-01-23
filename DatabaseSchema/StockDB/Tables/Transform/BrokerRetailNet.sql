-- Table: [Transform].[BrokerRetailNet]

CREATE TABLE [Transform].[BrokerRetailNet] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [BrokerRetailNet] [varchar](13) NULL,
    [NetValue] [bigint] NULL,
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL
,
    CONSTRAINT [pk_transform_brokerretailnet_uniquekey] PRIMARY KEY (UniqueKey)
);

CREATE INDEX [idx_transformbrokerretailnet_asxcodeobservationdate] ON [Transform].[BrokerRetailNet] (BrokerRetailNet, ASXCode, ObservationDate);