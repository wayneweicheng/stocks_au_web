-- Table: [Transform].[BrokerRetailNetSector]

CREATE TABLE [Transform].[BrokerRetailNetSector] (
    [Token] [varchar](200) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [BrokerRetailNet] [varchar](12) NULL,
    [NetValue] [bigint] NULL
);
