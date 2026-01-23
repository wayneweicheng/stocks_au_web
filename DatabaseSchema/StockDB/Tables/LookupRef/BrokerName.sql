-- Table: [LookupRef].[BrokerName]

CREATE TABLE [LookupRef].[BrokerName] (
    [BrokerCode] [varchar](50) NOT NULL,
    [BrokerName] [varchar](200) NOT NULL,
    [BrokerDescr] [varchar](MAX) NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [BrokerLevel] [smallint] NULL,
    [APIBrokerName] [varchar](100) NULL,
    [BrokerScore] [decimal](10,2) NULL,
    [IsDisabled] [bit] NULL
,
    CONSTRAINT [pk_lookrefbrokername_brokercode] PRIMARY KEY (BrokerCode)
);
