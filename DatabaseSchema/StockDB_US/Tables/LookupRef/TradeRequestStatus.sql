-- Table: [LookupRef].[TradeRequestStatus]

CREATE TABLE [LookupRef].[TradeRequestStatus] (
    [RequestStatus] [char](1) NOT NULL,
    [RequestStatusDescr] [varchar](100) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_lookupreftraderequeststatus_requeststatus] PRIMARY KEY (RequestStatus)
);
