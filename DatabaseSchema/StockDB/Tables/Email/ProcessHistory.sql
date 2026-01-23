-- Table: [Email].[ProcessHistory]

CREATE TABLE [Email].[ProcessHistory] (
    [ProcessHistoryID] [int] IDENTITY(1,1) NOT NULL,
    [AppName] [varchar](200) NOT NULL,
    [EmailSubject] [varchar](500) NOT NULL,
    [EmailFrom] [varchar](200) NOT NULL,
    [EmailTo] [varchar](200) NOT NULL,
    [EmailBody] [varchar](MAX) NULL,
    [EmailDate] [datetime] NULL,
    [CreateDate] [datetime] NULL,
    [SuggestedStocks] [varchar](MAX) NULL
,
    CONSTRAINT [pk_emailprocesshistory_processhistoryid] PRIMARY KEY (ProcessHistoryID)
);
