-- Table: [Transform].[BrokerRetailNet]

CREATE TABLE [Transform].[BrokerRetailNet] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [BrokerRetailNet] [varchar](13) NULL,
    [NetValue] [bigint] NULL
);

CREATE INDEX [idx_transformbrokerretailnet_asxcodeobservationdate] ON [Transform].[BrokerRetailNet] (ASXCode, ObservationDate);